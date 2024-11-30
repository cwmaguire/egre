%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_object).
-behaviour(gen_server).

-include("egre.hrl").
-include_lib("kernel/include/logger.hrl").

%% API.
-export([start_link/2]).
-export([populate/2]).
-export([attempt/2]).
-export([attempt/3]).
-export([attempt/4]).
-export([attempt_after/3]).
-export([attempt_after/4]).
-export([set/2]).
-export([props/1]).

%% Util
-export([has_pid/2]).
-export([value/3]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {props :: list(tuple()),
                prop_extract_fun :: fun(),
                log_tag :: atom()}).

-record(procs, {%limit = undefined :: undefined | {atom(), integer(), atom()},
                room = undefined :: pid(),
                done = [] :: ordsets:ordset(pid()),
                next = [] :: ordsets:ordset(pid()),
                subs = [] :: ordsets:ordset(pid())}).

-callback added(atom(), pid()) -> ok.
-callback removed(atom(), pid()) -> ok.

%% API.

-spec start_link(any(), proplist()) -> {ok, pid()}.
start_link(MaybeId, OriginalProps) ->
    crypto:rand_seed(),
    Id = id(MaybeId),

    Props =
        case egre_index:get(Id) of
            undefined ->
                Props_ = [{id, Id} | OriginalProps],
                egre_index:put(Props_),
                Props_;
            #object{properties = StoredProps} ->
                StoredProps
        end,

    {ok, Pid} = gen_server:start_link(?MODULE, Props, []),

    case proplists:get_value(pid, Props) of
        OldPid when is_pid(OldPid), OldPid /= Pid ->
            egre_index:replace_dead(OldPid, Pid);
        _ ->
            ok
    end,
    egre_index:update_pid(Id, Pid),
    {ok, Pid}.

id(_Id = undefined) ->
    binary_to_list(<< <<(X rem 96 + 31)>> || <<X>> <= crypto:strong_rand_bytes(20)>>);
id(Id) ->
    Id.

populate(Pid, ProcIds) ->
    send(Pid, {populate, ProcIds}).

attempt(Pid, Msg) ->
    attempt(Pid, Msg, [], _ShouldSubscribe = true).

attempt(Pid, Msg, ShouldSubscribe) ->
    attempt(Pid, Msg, [], ShouldSubscribe).

attempt(Pid, Event, Context, ShouldSubscribe) ->
    Subs = case ShouldSubscribe of
               true ->
                   [self()];
               _ ->
                   []
           end,
    send(Pid, {attempt, Event, Context, #procs{subs = Subs}}).

attempt_after(Millis, Pid, Msg) ->
    attempt_after(Millis, Pid, Msg, _ShouldSubscribe = true).

attempt_after(Millis, Pid, Msg, ShouldSubscribe) ->
    log([{stage, attempt_after},
         {object, self()},
         {target, Pid},
         {message, Msg},
         {millis, Millis}]),
    erlang:send_after(Millis, Pid, {send_after, Pid, Msg, ShouldSubscribe}).

set(Pid, Prop) ->
    send(Pid, {set, Prop}).

props(Pid) ->
    case is_process_alive(Pid) of
        true ->
            gen_server:call(Pid, props);
        _ ->
            []
    end.

%% util

has_pid(Props, Pid) ->
    lists:any(fun({_, Pid_}) when Pid == Pid_ -> true; (_) -> false end, Props).

%% gen_server.

init(Props) ->
    {ok, LogTag} = application:get_env(egre, tag),
    {ok, {M, F, A}} = application:get_env(egre, extract_fun),
    Fun =
        fun() ->
            process_flag(trap_exit, true),
            receive
                {'EXIT', From, Reason} ->
                    io:format("Watcher process ~p: ~p died because ~p",
                              [self(), From, Reason])
            end
        end,
    spawn_link(Fun),
    process_flag(trap_exit, true),
    attempt(self(), {self(), init}),
    {ok, #state{props = [{pid, self()} | Props],
                prop_extract_fun = fun M:F/A,
                log_tag = LogTag}}.

handle_call(props, _From, State) ->
    {reply, State#state.props, State};
handle_call({get, Key}, _From, State = #state{props = Props}) ->
    {reply, proplists:get_all_values(Key, Props), State};
handle_call(_Request, _From, State) ->
    {reply, ignored, State}.

handle_cast(Msg, State) ->
    handle_cast_(Msg, State).

handle_cast_({populate, ProcIds},
             State = #state{props = Props,
                            log_tag = LogTag}) ->
    log([{tag, LogTag},
         {object, self()},
         {?EVENT, populate},
         {source, self()} |
         Props]),
    egre_index:put(Props),
    {noreply, State#state{props = populate_(Props, ProcIds)}};
handle_cast_({set, Prop = {K, _}}, State = #state{props = Props}) ->
    {noreply, State#state{props = lists:keystore(K, 1, Props, Prop)}};
handle_cast_({attempt, Event, Context, Procs}, State = #state{props = Props}) ->
    IsExit = proplists:get_value(is_exit, Props, false),
    case maybe_attempt(Event, Context, Procs, IsExit, State) of
        Stop = {stop, _, _} ->
            Stop;
        Continue = {noreply, #state{props = Props2}} ->
            egre_index:put(Props2),
            Continue
    end;
handle_cast_({fail, Reason, Event, Context},
             State = #state{prop_extract_fun = PropExtractFun,
                            log_tag = LogTag}) ->
    case fail(Reason, Event, Context, State) of
        {stop, Reason2, Props, LogProps} ->
            {_, CustomProps} = PropExtractFun(Props),
            egre_index:put(Props),
            log([{tag, LogTag},
                 {stage, fail_stop},
                 {object, self()},
                 {owner, proplists:get_value(owner, Props, <<"">>)},
                 {message, Event},
                 {stop_reason, Reason} |
                 Props ++ CustomProps ++ LogProps]),
            egre_index:put(Props),
            % FIXME I think this will just cause the supervisor to restart it
            % Probably need to tell the supervisor to kill us
            {stop, {shutdown, Reason2}, State#state{props = Props}};
        {Props, _Reason, _Event, _Context, LogProps} ->
            {_, CustomProps} = PropExtractFun(Props),
            log([{stage, fail},
                 {object, self()},
                 {message, Event},
                 {stop_reason, Reason} |
                 Props ++ CustomProps ++ LogProps]),
            egre_index:put(Props),
            {noreply, State#state{props = Props}}
    end;
handle_cast_({succeed, Msg, Context},
             State = #state{prop_extract_fun = PropExtractFun,
                            log_tag = LogTag}) ->
    case succeed(Msg, Context, State) of
        {stop, Reason, Props, LogProps} ->
            {_, CustomProps} = PropExtractFun(Props),
            log([{tag, LogTag},
                 {stage, succeed},
                 {event, stop},
                 {object, self()},
                 {message, Msg},
                 {stop_reason, Reason} |
                 Props ++ CustomProps ++ LogProps]),
            egre_index:put(Props),
            Self = self(),
            spawn(fun() ->
                      % TODO clean out backups and index
                      % There's a terminate function that I don't seem to be using
                      ct:pal("~p Spawning child terminator for ~p through supervisor", [self(), Self]),
                      supervisor:terminate_child(egre_object_sup, Self)
                  end),
            {noreply, State#state{props = Props}};
        {Props, LogProps} ->
            {_, CustomProps} = PropExtractFun(Props),
            log([{tag, LogTag},
                 {stage, succeed},
                 {object, self()},
                 {message, Msg} |
                 Props ++ CustomProps ++ LogProps]),
            egre_index:put(Props),
            {noreply, State#state{props = Props}}
    end.

handle_info({'EXIT', From, Reason},
            State = #state{props = Props,
                           prop_extract_fun = PropExtractFun,
                           log_tag = LogTag}) ->
    ct:pal("~p:handle_info({'EXIT', From: ~p, Reason: ~p}) - ~p~n", [?MODULE, From, Reason, self()]),
    {_, CustomProps} = PropExtractFun(Props),
    log([{tag, LogTag},
         {?EVENT, exit},
         {object, self()},
         {source, From},
         {reason, Reason} |
         Props ++ CustomProps]),
    ?LOG_INFO("Process ~p died~n", [From]),
    egre_index:subscribe_dead(self(), From),
    Props2 = mark_pid_dead(From, Props),
    egre_index:put(Props2),
    {stop, normal, State#state{props = Props2}};
handle_info({replace_pid, OldPid, NewPid}, State = #state{props = Props})
  when is_pid(OldPid), is_pid(NewPid) ->
    ct:pal("~p:handle_info({replace_pid...~n", [?MODULE]),
    Props2 = replace_pid(Props, OldPid, NewPid),
    egre_index:unsubscribe_dead(self(), OldPid),
    egre_index:put(Props2),
    {noreply, State#state{props = Props2}};
handle_info({send_after, Pid, Msg, ShouldSub}, State) when is_pid(Pid) ->
    attempt(Pid, Msg, ShouldSub),
    {noreply, State};
handle_info(Unknown,
            State = #state{props = Props,
                           prop_extract_fun = PropExtractFun,
                           log_tag = LogTag}) ->
    {_, CustomProps} = PropExtractFun(Props),
    log([{tag, LogTag},
         {?EVENT, unknown_message},
         {object, self()},
         {message, Unknown} |
         Props ++ CustomProps]),
    {noreply, State}.

terminate(Reason,
          _State = #state{props = Props,
                          prop_extract_fun = PropExtractFun,
                          log_tag = LogTag}) ->
    {_, CustomProps} = PropExtractFun(Props),
    log([{tag, LogTag},
         {?EVENT, shutdown},
         {object, self()},
         {reason, Reason} |
         Props ++ CustomProps]),
    egre_index:del(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% internal

maybe_attempt(Msg,
              Context,
              Procs = #procs{room = Room},
              _IsExit = true,
              State = #state{props = Props})
        when Room  /= undefined ->
    _ = case exit_has_room(Props, Room) of
            true ->
                attempt_(Msg, Context, Procs, State);
            false ->
                _ = handle(succeed, Msg, Context, done(self(), Procs), Props),
                State
        end;
maybe_attempt(Msg, Context, Procs, _, State) ->
    attempt_(Msg, Context, Procs, State).

exit_has_room(Props, Room) ->
    HasRoom = fun({{room, _}, R}) ->
                  R == Room;
                 (_) ->
                  false
              end,
    lists:any(HasRoom, Props).

attempt_(Event,
         Context,
         Procs,
         State = #state{props = Props,
                        prop_extract_fun = PropExtractFun,
                        log_tag = LogTag}) ->
    {CustomData, CustomProps} = PropExtractFun(Props),
    {RulesModule,
     Results = #result{result = Result,
                       event = Event2,
                       context = Context2,
                       subscribe = ShouldSubscribe,
                       props = Props2,
                       log = LogProps}}
      = ensure_context(Context,
          ensure_event(Event,
                       run_rules({CustomData,
                                  Props,
                                  Event,
                                  Context}))),
    %ct:pal("~p:~p: Results~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Results]),
    log([{tag, LogTag},
         {stage, attempt},
         {object, self()},
         {message, Event},
         {rules_module, rules_mod_suffix(RulesModule)},
         {subscribe, ShouldSubscribe},
         {room, Procs#procs.room} |
         Props2] ++
         CustomProps ++
         LogProps ++
         result_tuples(Result)),

    MergedProcs = merge(self(), is_room(Props), Results, Procs),
    State2 = State#state{props = Props2},
    case handle(Result, Event2, Context2, MergedProcs, Props2) of
        stop ->
            % XXX I don't think I should be stopping processes on attempt

            % TODO clean out backups and index
            % There's a terminate function that I don't seem to be using
            Self = self(),
            spawn(fun() ->
                      supervisor:terminate_child(egre_object_sup, Self)
                  end),
            {noreply, State2};
        _ ->
            {noreply, State2}
    end.

is_room(Props) ->
    proplists:get_value(is_room, Props, false).

result_tuples({fail, Reason}) when is_binary(Reason) ->
    [{result, fail}, {reason, Reason}];
result_tuples({fail, Reason}) when is_list(Reason) ->
    [{result, fail}, {reason, list_to_binary(Reason)}];
result_tuples({fail, Reason}) when is_atom(Reason) ->
    [{result, fail}, {reason, atom_to_binary(Reason, utf8)}];
result_tuples(Any = {fail, Any}) ->
    [{result, fail}, {reason, Any}];
result_tuples({resend, Target, Message}) ->
    [{result, resend}, {resend_to, Target}, {new_message, Message}];
result_tuples(succeed) ->
    [{result, succeed}];
result_tuples({broadcast, Message}) ->
    [{result, broadcast}, {new_message, Message}];
result_tuples(stop) ->
    [{result, stop}].

run_rules(Attempt = {_, Props, _, _}) ->
    RulesModules = proplists:get_value(rules, Props),
    handle_attempt(RulesModules, Attempt).

handle_attempt(undefined, _) ->
    throw(missing_rules_property_in_object);
handle_attempt([], {_Custom, Props, Event, Context}) ->
    _DefaultResponse =
        {no_rules_module,
         #result{subscribe = false,
                 event = Event,
                 props = Props,
                 context = Context}};
handle_attempt([MapOrModule | RulesModules], Attempt) ->
    {Module, Fun} = attempt_function(MapOrModule),
    case Fun(Attempt) of
        undefined ->
            handle_attempt(RulesModules, Attempt);
        Result ->
            {Module, Result}
    end.

attempt_function(#{attempt := {ModuleName, Fun}}) ->
    {ModuleName, Fun};
attempt_function(Module) when is_atom(Module) ->
    {Module, fun Module:attempt/1}.

ensure_event(Event, {RulesModule, Result = #result{event = undefined}}) ->
    {RulesModule, Result#result{event = Event}};
ensure_event(_, Tuple) ->
    Tuple.

ensure_context(Context, {RulesModule, Result = #result{context = undefined}}) ->
    {RulesModule, Result#result{context = Context}};
ensure_context(_, Tuple) ->
    Tuple.

handle({resend, Target, Event}, _OrigEvent, Context, _NoProcs, _Props) ->
    send(Target, {attempt, Event, Context, #procs{}});
handle({fail, Reason}, Event, Context, Procs = #procs{subs = Subs}, _Props) ->
    [send(Sub, {fail, Reason, Event, Context}, Procs) || Sub <- Subs];
handle(succeed, Event, Context, Procs = #procs{subs = Subs}, _Props) ->
    _ = case next(Procs) of
        {Next, Procs2} ->
            send(Next, {attempt, Event, Context, Procs2});
        none ->
            [send(Sub, {succeed, Event, Context}, Procs) || Sub <- Subs]
    end;
handle({broadcast, Event}, _OrigEvent, Context, _Procs, Props) ->
    [broadcast(Pid, Event, Context) || Pid <- pids(Props, broadcast_pid_filter)];
% XXX what's this used by?
handle(stop, _Event, Context, _Procs, Props) ->
    [broadcast(Proc, stop, Context) || Proc <- pids(Props, stop_pid_filter)],
    stop.

broadcast(Pid, Event, Context) ->
    attempt_after(0, Pid, Event, Context).

send(Pid, SendMsg = {fail, _Reason, _Event, _Context}, _Procs) ->
    send_(Pid, SendMsg);
send(Pid, SendMsg = {succeed, _Event, _Context}, _Procs) ->
    send_(Pid, SendMsg).

send(Pid, SendMsg = {attempt, _Event, _Context, _Procs}) ->
    send_(Pid, SendMsg);
send(Pid, Msg) ->
    send_(Pid, Msg).

send_(Pid, Msg) ->
    gen_server:cast(Pid, Msg).

populate_(Props, IdPids) ->
    {_, Props2} = lists:foldl(fun set_pid/2, {IdPids, []}, Props),
    Props2.

set_pid(Prop = {id, _V}, {IdPids, Props}) ->
    {IdPids, [Prop | Props]};
set_pid({K, {{pid, V1}, {pid, V2}}}, {IdPids, Props}) ->
    MaybeProc1 = maybe_proc(V1, IdPids),
    MaybeProc2 = maybe_proc(V2, IdPids),
    {IdPids, [{K, {MaybeProc1, MaybeProc2}} | Props]};
set_pid({K, {{pid, V1}, V2}}, {IdPids, Props}) ->
    {IdPids, [{K, {maybe_proc(V1, IdPids), V2}} | Props]};
set_pid({K, Map = #{}}, {IdPids, Props}) ->
    Map2 = maps:fold(fun(K_, V, MapAcc) ->
                             MapAcc#{maybe_proc(K_, IdPids) => V}
                     end,
                     #{},
                     Map),
    {IdPids, [{K, Map2} | Props]};
set_pid({K, V}, {IdPids, Props}) ->
    {IdPids, [{K, maybe_proc(V, IdPids)} | Props]}.

maybe_proc(MaybeId, IdPids) when is_atom(MaybeId) ->
    proplists:get_value(MaybeId, IdPids, MaybeId);
maybe_proc(Value, _) ->
    Value.

pids(Props, PidFilterKey) ->
    PidFilterFun = proplists:get_value(PidFilterKey, Props, fun default_pid_filter/1),
    lists:filtermap(PidFilterFun, Props).

default_pid_filter({_, Pid}) when is_pid(Pid) ->
    {true, Pid};
default_pid_filter({_, {Pid, Ref}}) when is_pid(Pid), is_reference(Ref) ->
    {true, Pid};
default_pid_filter(_) ->
    false.

merge(_Self, _IsRoom, #result{result = {resend, _, _}}, _Props) ->
    undefined;
merge(_Self, _IsRoom, #result{result = {broadcast, _}}, _Props) ->
    undefined;
merge(Self,
      IsRoom = true,
      Result,
      Procs = #procs{room = undefined}) ->
    merge(Self, IsRoom, Result, Procs#procs{room = Self});
merge(Self,
      _,
      #result{subscribe = ShouldSubscribe,
              props = Props},
      Procs = #procs{}) ->
    merge_(Self,
           sub(Procs, ShouldSubscribe),
           pids(Props, graph_pid_filter)).

merge_(Self, Procs, NewProcs) ->
    Done = done(Self, Procs#procs.done),
    New = ordsets:subtract(ordsets:from_list(NewProcs), Done),
    Next = ordsets:union(Procs#procs.next, New),
    Procs#procs{done = Done, next = Next}.

done(Proc, Procs = #procs{done = Done}) ->
    Procs#procs{done = done(Proc, Done)};
done(Proc, Done) ->
    ordsets:union(Done, [Proc]).

sub(Procs = #procs{subs = Subs}, true) ->
    Procs#procs{subs = ordsets:union(Subs, [self()])};
sub(Procs, _) ->
    Procs.

next(Procs = #procs{next = NextSet}) ->
    Next = ordsets:to_list(NextSet),
    case(Next) of
        [] ->
            none;
        _ ->
            %TODO ordsets are already lists, remove this. If anything, use from_list/1
            NextProc = hd(ordsets:to_list(Next)),
            {NextProc, Procs#procs{next = ordsets:del_element(NextProc, Next)}}
    end.

succeed(Message, Context, #state{props = Props}) ->
    Rules = proplists:get_value(rules, Props),
    handle_success(Rules, {Props, [], Message, Context}).

handle_success(_NoMoreRules = [], {Props, LogProps, _Message, _Context}) ->
    {Props, LogProps};
handle_success([MapOrMod | Rules], {Props, LogProps, Message, Context}) ->
    SucceedFun = succeed_function(MapOrMod),
    case SucceedFun({Props, Message, Context}) of
        undefined ->
            handle_success(Rules, {Props, LogProps, Message, Context});
        {stop, Reason, Props2, LogProps2} ->
            MergedLogProps = merge_log_props(LogProps, LogProps2),
            {stop, Reason, Props2, MergedLogProps};
        {Props2, LogProps2} ->
            MergedLogProps = merge_log_props(LogProps, LogProps2),
            handle_success(Rules, {Props2, MergedLogProps, Message, Context});
        Props2 ->
            handle_success(Rules, {Props2, LogProps, Message, Context})
    end.

succeed_function(#{succeed := Fun}) ->
    Fun;
succeed_function(Module) when is_atom(Module) ->
    fun Module:succeed/1.

merge_log_props(Logs1, Logs2) ->
    lists:keymerge(1,
                   lists:keysort(1, Logs1),
                   lists:keysort(1, Logs2)).

fail(Reason, Event, Context, #state{props = Props}) ->
    Rules = proplists:get_value(rules, Props),
    Acc = {Props, Reason, Event, Context, _LogProps = []},
    lists:foldl(fun handle_fail/2, Acc, Rules).

handle_fail(_, Response = {stop, _Reason, _Props, _LogProps}) ->
    Response;
handle_fail(MapOrMod, {Props, Reason, Event, Context, LogProps}) ->
    FailFun = fail_function(MapOrMod),
    case FailFun({Props, Reason, Event, Context}) of
        undefined ->
            {Props, Reason, Event, Context, LogProps};
        {stop, Reason2, Props2, LogProps2} ->
            MergedLogProps = merge_log_props(LogProps, LogProps2),
            {stop, Reason2, Props2, MergedLogProps};
        {Props2, LogProps2} ->
            {Props2, Reason, Event, Context, LogProps ++ LogProps2};
        Props2 when is_list(Props2) ->
            {Props2, Reason, Event, Context, LogProps}
    end.

fail_function(#{fail := Fun}) ->
    Fun;
fail_function(Module) when is_atom(Module) ->
    fun Module:fail/1.

value(Prop, Props, integer) ->
    prop(Prop, Props, fun is_integer/1, 0);
value(Prop, Props, boolean) ->
    prop(Prop, Props, fun is_boolean/1, false).

prop(Prop, Props, Fun, Default) ->
    Val = proplists:get_value(Prop, Props),
    case Fun(Val) of
        true ->
            Val;
        _ ->
            Default
    end.

mark_pid_dead(Pid, Props) when is_list(Props) ->
    [mark_pid_dead(Pid, Prop) || Prop <- Props];
mark_pid_dead(Pid, {K, Pid}) ->
    {K, {dead, Pid}};
mark_pid_dead(Pid, {K, {Pid, Value}}) ->
    {K, {{dead, Pid}, Value}};
mark_pid_dead(_, KV) ->
    KV.

replace_pid(Props, OldPid, NewPid) when is_list(Props) ->
    [replace_pid(Prop, OldPid, NewPid) || Prop <- Props];
replace_pid({K, {dead, OldPid}}, OldPid, NewPid) ->
    {K, NewPid};
replace_pid({K, {{dead, OldPid}, Value}}, OldPid, NewPid)
  when is_atom(Value) ->
    {K, {NewPid, Value}};
replace_pid(Prop, _, _) ->
    Prop.

log(Props0) ->
    Props = egre_event_log:flatten(Props0),
    egre_event_log:log(debug, [{module, ?MODULE} | Props]).

rules_mod_suffix(Module) when is_atom(Module) ->
    case atom_to_list(Module) of
        "rules_" ++ Suffix ->
            Suffix;
        _ ->
            Module
    end;
rules_mod_suffix(Other) ->
    Other.
