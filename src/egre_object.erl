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
                extract_record_fun :: fun()}).

-record(procs, {limit = undefined :: undefined | {atom(), integer(), atom()},
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
    attempt(Pid, Msg, _ShouldSubscribe = true).

attempt(Pid, Msg, ShouldSubscribe) ->
    Subs = case ShouldSubscribe of
               true ->
                   [self()];
               _ ->
                   []
           end,
    send(Pid, {attempt, Msg, #procs{subs = Subs}}).

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
                extract_record_fun = fun M:F/A}}.

handle_call(props, _From, State) ->
    {reply, State#state.props, State};
handle_call({get, Key}, _From, State = #state{props = Props}) ->
    {reply, proplists:get_all_values(Key, Props), State};
handle_call(_Request, _From, State) ->
    {reply, ignored, State}.

handle_cast(Msg, State) ->
    handle_cast_(Msg, State).

handle_cast_({populate, ProcIds}, State = #state{props = Props}) ->
    log([{stage, none},
         {object, self()},
         {?EVENT, populate},
         {source, self()} |
         Props]),
    egre_index:put(Props),
    {noreply, State#state{props = populate_(Props, ProcIds)}};
handle_cast_({set, Prop = {K, _}}, State = #state{props = Props}) ->
    {noreply, State#state{props = lists:keystore(K, 1, Props, Prop)}};
handle_cast_({attempt, Msg, Procs}, State = #state{props = Props}) ->
    %ct:pal("~p:handle_cast_({attempt, ~p, ...~n", [?MODULE, Msg]),
    IsExit = proplists:get_value(is_exit, Props, false),
    case maybe_attempt(Msg, Procs, IsExit, State) of
        Stop = {stop, _, _} ->
            Stop;
        Continue = {noreply, #state{props = Props2}} ->
            egre_index:put(Props2),
            Continue
    end;
handle_cast_({fail, Reason, Msg}, State = #state{extract_record_fun = ExtractRecordFun}) ->
    case fail(Reason, Msg, State) of
        {stop, Props, LogProps} ->
            {_, RecordProps} = ExtractRecordFun(Props),
            egre_index:put(Props),
            log([{stage, fail_stop},
                 {object, self()},
                 {owner, proplists:get_value(owner, Props)},
                 {message, Msg},
                 {stop_reason, Reason} |
                 Props ++ RecordProps ++ LogProps]),
            egre_index:put(Props),
            % FIXME I think this will just cause the supervisor to restart it
            % Probably need to tell the supervisor to kill us
            {stop, {shutdown, Reason}, State#state{props = Props}};
        {Props, _, _, LogProps} ->
            {_, RecordProps} = ExtractRecordFun(Props),
            log([{stage, fail},
                 {object, self()},
                 {message, Msg},
                 {stop_reason, Reason} |
                 Props ++ RecordProps ++ LogProps]),
            egre_index:put(Props),
            {noreply, State#state{props = Props}}
    end;
handle_cast_({succeed, Msg},
             State = #state{extract_record_fun = ExtractRecordFun}) ->
    case succeed(Msg, State) of
        {stop, Reason, Props, LogProps} ->
            {_, RecordProps} = ExtractRecordFun(Props),
            log([{stage, succeed},
                 {event, stop},
                 {object, self()},
                 {message, Msg},
                 {stop_reason, Reason} |
                 Props ++ RecordProps ++ LogProps]),
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
            {_, RecordProps} = ExtractRecordFun(Props),
            log([{stage, succeed},
                 {object, self()},
                 {message, Msg} |
                 Props ++ RecordProps ++ LogProps]),
            egre_index:put(Props),
            {noreply, State#state{props = Props}}
    end.

handle_info({'EXIT', From, Reason},
            State = #state{props = Props,
                           extract_record_fun = ExtractRecordFun}) ->
    ct:pal("~p:handle_info({'EXIT', From: ~p, Reason: ~p}) - ~p~n", [?MODULE, From, Reason, self()]),
    {_, RecordProps} = ExtractRecordFun(Props),
    log([{?EVENT, exit},
         {object, self()},
         {source, From},
         {reason, Reason} |
         Props ++ RecordProps]),
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
                           extract_record_fun = ExtractRecordFun}) ->
    {_, RecordProps} = ExtractRecordFun(Props),
    log([{?EVENT, unknown_message},
         {object, self()},
         {message, Unknown} |
         Props ++ RecordProps]),
    {noreply, State}.

terminate(Reason,
          _State = #state{props = Props,
                          extract_record_fun = ExtractRecordFun}) ->
    {_, RecordProps} = ExtractRecordFun(Props),
    log([{?EVENT, shutdown},
         {object, self()},
         {reason, Reason} |
         Props ++ RecordProps]),
    egre_index:del(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% internal

maybe_attempt(Msg,
              Procs = #procs{room = Room},
              _IsExit = true,
              State = #state{props = Props})
        when Room  /= undefined ->
    _ = case exit_has_room(Props, Room) of
            true ->
                attempt_(Msg, Procs, State);
            false ->
                _ = handle(succeed, Msg, done(self(), Procs), Props),
                State
        end;
maybe_attempt(Msg, Procs, _, State) ->
    attempt_(Msg, Procs, State).

exit_has_room(Props, Room) ->
    HasRoom = fun({{room, _}, R}) ->
                  R == Room;
                 (_) ->
                  false
              end,
    lists:any(HasRoom, Props).

attempt_(Msg,
         Procs,
         State = #state{props = Props,
                        extract_record_fun = ExtractRecordFun}) ->
    {Record, RecordProps} = ExtractRecordFun(Props),
    {RulesModule,
     Results = {Result,
                Msg2,
                ShouldSubscribe,
                Props2,
                LogProps}}
      = ensure_log_props(
          ensure_message(Msg,
                         run_rules({Record, Props, Msg}))),
    log([{stage, attempt},
         {object, self()},
         {message, Msg},
         {rules_module, RulesModule},
         {subscribe, ShouldSubscribe},
         {room, Procs#procs.room} |
         Props2] ++
         RecordProps ++
         LogProps ++
         result_tuples(Result)),
    %ct:pal("~p:~p: PREMERGE: Self = ~p; Msg = ~p; Procs~n\t~p~nResult: ~p~n",
           %[?MODULE, ?FUNCTION_NAME, self(), Msg, Procs, Result]),
    MergedProcs = merge(self(), is_room(Props), Results, Procs),
    %ct:pal("~p:~p: Self = ~p; Msg = ~p; MergedProcs~n\t~p~n",
           %[?MODULE, ?FUNCTION_NAME, self(), Msg, MergedProcs]),
    State2 = State#state{props = Props2},
    case handle(Result, Msg2, MergedProcs, Props2) of
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

run_rules(Attempt = {_, Props, _}) ->
    RulesModules = proplists:get_value(rules, Props),
    handle_attempt(RulesModules, Attempt).

handle_attempt(undefined, _) ->
    throw(missing_rules_property_in_object);
handle_attempt([], {_, Props, _}) ->
    _DefaultResponse = {no_rules_module, {succeed, false, Props}};
handle_attempt([RulesModule | RulesModules], Attempt) ->
    %{_, Props, _} = Attempt,
    %Name = proplists:get_value(name, Props, "___"),
    %log([Name, self(), <<" running rules ">>, Rules]),
    case RulesModule:attempt(Attempt) of
        undefined ->
            handle_attempt(RulesModules, Attempt);
        Result ->
            {RulesModule, Result}
    end.

ensure_message(Msg, {RulesModule, {Result, Sub, Props}})
  when is_atom(Sub), is_list(Props) ->
    {RulesModule, {Result, Msg, Sub, Props}};
ensure_message(Msg, {RulesModule, {Result, Sub, Props, Log}})
  when is_atom(Sub), is_list(Props), is_list(Log) ->
    {RulesModule, {Result, Msg, Sub, Props, Log}};
ensure_message(_, T) ->
    T.

ensure_log_props({Handler, {Result, Msg, Sub, Props}})
  when is_atom(Sub), is_tuple(Msg), is_list(Props) ->
    {Handler, {Result, Msg, Sub, Props, []}};
ensure_log_props(WithLogProps) ->
    WithLogProps.


handle({resend, Target, Msg}, _OrigMsg, _NoProcs, _Props) ->
    send(Target, {attempt, Msg, #procs{}});
handle({fail, Reason}, Msg, Procs = #procs{subs = Subs}, _Props) ->
    [send(Sub, {fail, Reason, Msg}, Procs) || Sub <- Subs];
handle(succeed, Msg, Procs = #procs{subs = Subs}, _Props) ->
    _ = case next(Procs) of
        {Next, Procs2} ->
            send(Next, {attempt, Msg, Procs2});
        none ->
            [send(Sub, {succeed, Msg}, Procs) || Sub <- Subs]
    end;
handle({broadcast, Msg}, _Msg, _Procs, Props) ->
    [broadcast(Pid, Msg) || Pid <- pids(Props, broadcast_pid_filter)];
% XXX what's this used by?
handle(stop, _Msg, _Procs, Props) ->
    [broadcast(Proc, stop) || Proc <- pids(Props, stop_pid_filter)],
    stop.

broadcast(Pid, Msg) ->
    attempt_after(0, Pid, Msg).

send(Pid, SendMsg = {fail, _Reason, _Msg}, _Procs) ->
    send_(Pid, SendMsg);
send(Pid, SendMsg = {succeed, _Msg}, _Procs) ->
    send_(Pid, SendMsg).

send(Pid, SendMsg = {attempt, _Msg, _Procs}) ->
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
set_pid({K, {{pid, V1}, V2}}, {IdPids, Props}) ->
    {IdPids, [{K, {maybe_proc(V1, IdPids), V2}} | Props]};
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

merge(_, _, {{resend, _, _, _}, _, _, _, _}, _) ->
    undefined;
merge(_, _, {{broadcast, _}, _, _, _, _}, _) ->
    undefined;
merge(Self,
      IsRoom = true,
      Results,
      Procs = #procs{room = undefined}) ->
    merge(Self, IsRoom, Results, Procs#procs{room = Self});
merge(Self,
      _,
      {_,
       _,
       ShouldSubscribe,
       Props,
       _},
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

succeed(Message, #state{props = Props}) ->
    Rules = proplists:get_value(rules, Props),
    handle_success(Rules, {Props, [], Message}).

handle_success(_NoMoreRules = [], {Props, LogProps, _Message}) ->
    {Props, LogProps};
handle_success([Handler | Rules], {Props, LogProps, Message}) ->
    case Handler:succeed({Props, Message}) of
        {stop, Reason, Props2, LogProps2} ->
            MergedLogProps = merge_log_props(LogProps, LogProps2),
            {stop, Reason, Props2, MergedLogProps};
        {Props2, LogProps2} ->
            MergedLogProps = merge_log_props(LogProps, LogProps2),
            handle_success(Rules, {Props2, MergedLogProps, Message});
        Props2 ->
            handle_success(Rules, {Props2, LogProps, Message})
    end.

merge_log_props(Logs1, Logs2) ->
    lists:keymerge(1,
                   lists:keysort(1, Logs1),
                   lists:keysort(1, Logs2)).

fail(Reason, Message, #state{props = Props}) ->
    Rules = proplists:get_value(rules, Props),
    Acc = {Props, Reason, Message, _LogProps = []},
    lists:foldl(fun handle_fail/2, Acc, Rules).

handle_fail(_, Response = {stop, _Props, _LogProps}) ->
    Response;
handle_fail(HandlerModule, {Props, Reason, Message, LogProps}) ->
    case HandlerModule:fail({Props, Reason, Message}) of
        {Props2, LogProps2} ->
            {Props2, Reason, Message, LogProps ++ LogProps2};
        Props2 ->
            {Props2, Reason, Message, LogProps}
    end.

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
