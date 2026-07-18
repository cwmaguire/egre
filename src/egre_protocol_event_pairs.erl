-module(egre_protocol_event_pairs).

-export([extract/2]).
-export([get_events/1]).
-export([get_events/2]).
-export([write_events/1]).

-define(API_FUNCTION_ARITY, 1).
-define(PROPS, egre_protocol_props_inference).
-define(ARGS, egre_protocol_args_inference).
-define(GUARDS, egre_protocol_guards_inference).
-define(INDEX, egre_protocol_event_index).

-record(state, {events = [],
                type_map = #{},
                variables = #{},
                props = [],
                prop_types = #{}}).

%% FIXME
%%  src/rules/rules_body_part_inject_self.erl: error in parse transform 'egre_protocol_parse_transform':
%%  exception error: no function clause matching egre_protocol_event_chains:index_variable({call,{atom,self},[]},{2,[1,move,from],[{1,<<"Item">>}],[],#{}}) (src/egre_protocol_event_chains.erl, line 197)

extract(ApiFuns, PropertyTypes) ->
    [{{Module, Fun, _}, _} | _] = ApiFuns,
    % io:format(user, "Module:Fun = ~p:~p~n", [Module, Fun]),
    %egre_dbg:add(egre_protocol_event_pairs, maybe_add_attempt_types),
    % egre_dbg:add(egre_protocol_event_pairs, type_inference_equals),
    % egre_dbg:add(egre_protocol_event_pairs, event),
    % egre_dbg:add(egre_protocol_event_pairs, maybe_var_event),
    % egre_dbg:add(egre_protocol_event_pairs, conjunction_type_inference),
    % egre_dbg:add(egre_protocol_event_pairs, indexed_event),
    % egre_dbg:add(egre_protocol_event_pairs, maybe_add_attempt_types),
    % egre_dbg:add(?PROPS, find_prop_types),
    % egre_dbg:add(?PROPS, maybe_property_type),
    Events = get_events(ApiFuns, PropertyTypes),
    Keys = [K || {K, _} <- ApiFuns],
    case Events of
        [] ->
            [io:format(user, "No events for ~s:~p - ~p~n", [Module, Fun, K]) || K <- Keys];
        _ ->
            ok
    end,
    egre_dbg:stop(),
    write_events(Events).

get_events(ApiClauses) ->
  get_events(ApiClauses, _PropertyTypes = #{}).

get_events(ApiClauses, PropertyTypes) ->
    {Events, _, _} = lists:foldl(fun get_event_pairs/2, {[], #{}, PropertyTypes}, ApiClauses),
    Events.

write_events([]) ->
    ok;
write_events(Events = [[Module | _] | _]) ->
    {ok, IO} = file:open(<<"events/", Module/binary, "_events.bert">>, [write]),
    file:write(IO, term_to_binary(Events)),
    file:close(IO).


get_event_pairs({_K, {clause, [{var, '_'}], _, _}}, Acc) ->
    Acc;
get_event_pairs(ApiFun = {{Module, Function, ?API_FUNCTION_ARITY}, {clause, Arguments, [Conjunction], Body}},
                {Events, AttemptTypeIndexes, PropertyTypes})
  when Function == attempt;
       Function == succeed ->

    io:format(user, "~n~n~n", []),
    io:format(user, "===================================================================================~n", []),
    io:format(user, "Module: ~p~n", [Module]),
    io:format(user, "Function: ~p~n", [Function]),
    io:format(user, "===================================================================================~n", []),
    io:format(user, "AttemptTypeIndexes: ~p~n", [AttemptTypeIndexes]),
    io:format(user, "Arguments: ~p~n", [Arguments]),
    io:format(user, "Conjunction: ~p~n", [Conjunction]),
    io:format(user, "Body: ~n~p~n~n", [Body]),

    io:format(user, "Getting custom data types with PropertyTypes: ~p~n", [PropertyTypes]),
    TypeMap1 = ?ARGS:infer(Function, Arguments, PropertyTypes),
    io:format(user, "~nTypeMap after custom data type inference:~n~p~n", [TypeMap1]),
    % TypeMap1 = #{},
    TypeMap2 = lists:foldl(fun ?GUARDS:infer/2, TypeMap1, Conjunction),

    io:format(user, "~nTypeMap after conjunction type inference:~n~p~n", [TypeMap2]),

    % io:format(user, "TypeMap = ~p~n", [TypeMap]),
    % State = props(#state{type_map = TypeMap2}, Function, Arguments),

    Event = event(Function, Arguments),

    io:format(user, "~nEvent: ~p~n", [Event]),

    State = 
        case ?PROPS:maybe_props_var(Function, Arguments) of
            undefined ->
                #state{type_map = TypeMap2,
                       prop_types = PropertyTypes};
            PropsVar ->
                State_ = #state{type_map = TypeMap2,
                                prop_types = PropertyTypes,
                                props = [PropsVar]},
                lists:foldl(fun ?PROPS:find_prop_types/2, State_, Body)
        end,

    io:format(user, "Prop Types:~n~p~n", [State#state.type_map]),

    io:format(user, "~n~n", []),
    io:format(user, "====================================~n", []),
    io:format(user, "fold reaction_events/2 over the ~p body~n", [Function]),
    io:format(user, "====================================~n", []),

    {ReactionEvents, TypeMap4} =
        case lists:foldl(fun reaction_events/2, State, Body) of
            #state{events = [],
                   type_map = TypeMap3} ->
                {[undefined], TypeMap3};
            #state{events = StateEvents,
                   type_map = TypeMap3} ->
                {StateEvents, TypeMap3}
        end,

    io:format(user, "ReactionEvents: ~p~n", [ReactionEvents]),
    io:format(user, "TypeMap4: ~p~n", [TypeMap4]),

    io:format(user, "~n~n", []),
    io:format(user, "====================================~n", []),
    io:format(user, "Run indexed_event/2 on the event ~p~n", [Function]),
    io:format(user, "====================================~n", []),

    ActionEvent =
        {IndexedEvent, IndexedVariables, IndexedTypes} =
            ?INDEX:index_event(Event, State#state{type_map = TypeMap4}),

    io:format(user, "IndexedEvent: ~p~n", [IndexedEvent]),
    io:format(user, "IndexedVariables: ~p~n", [IndexedVariables]),
    io:format(user, "IndexedTypes: ~p~n", [IndexedTypes]),

    io:format(user, "~n~n", []),
    io:format(user, "====================================~n", []),
    io:format(user, "maybe merge existing types with succeed types (merge_types/2)~n", []),
    io:format(user, "====================================~n", []),

    %% Infer succeed event types from matching attempt event types
    ActionEvent2 = {_, _, MaybeMergedIndexTypes} =
        case {Function, AttemptTypeIndexes} of
            {succeed, #{IndexedEvent := TypeIndex}} ->
                io:format(user, "Found index event variable type map for ~p~n~p~n", [IndexedEvent, TypeIndex]),
                {IndexedEvent, IndexedVariables, merge_type_indexes(IndexedTypes, TypeIndex)};
            _ ->
                io:format(user, "Not a succeed event (~p) or no matching AttemptTypeIndex for event~n", [Function]),
                ActionEvent
        end,

    io:format(user, "AttemptTypeIndexes: ~p~n", [AttemptTypeIndexes]),
    io:format(user, "IndexedEvent: ~p~n", [IndexedEvent]),
    io:format(user, "Matching AttemptTypeIndexes? ~p~n", [maps:get(IndexedEvent, AttemptTypeIndexes, no)]),
    io:format(user, "Merged IndexedTypes:~nFrom (Original) ~p~nTo (New) ~p~n", [IndexedTypes, MaybeMergedIndexTypes]),

    io:format(user, "~n~n", []),
    io:format(user, "====================================~n", []),
    io:format(user, "maybe add attempt types~n", []),
    io:format(user, "Is this if we have only one succeed match for an attempt subscription?~n", []),
    io:format(user, "Or, if we only have one attempt that has this exact shape?~n", []),
    io:format(user, "====================================~n", []),

    AttemptTypeIndexes2 =
        case {Function, IndexedTypes} of
            {attempt, []} ->
                io:format(user, "No indexed types~n", []),
                AttemptTypeIndexes;
            {attempt, _} ->
                io:format(user, "`attempt` with indexed types ~p~nMaybe add attempt types: ~p, ~p, ~p, ~n",
                          [IndexedTypes, IndexedEvent, IndexedTypes, AttemptTypeIndexes]),
                maybe_add_attempt_types(IndexedEvent, IndexedTypes, AttemptTypeIndexes);
            _ ->
                io:format(user, "Not an attempt event (~p)~n", [Function]),
                AttemptTypeIndexes
        end,

    io:format(user, "~n~n", []),
    io:format(user, "====================================~n", []),
    io:format(user, "Did we update attempt type variable maps?~n", []),
    io:format(user, "====================================~n", []),

    case AttemptTypeIndexes of
        AttemptTypeIndexes2 ->
            io:format(user, "No~n", []);
        _ ->
            io:format(user, "Yes: ~nFrom: ~p~nTo: ~p~n",
                      [AttemptTypeIndexes, AttemptTypeIndexes2])
    end,

    io:format(user, "~n~n", []),
    io:format(user, "====================================~n", []),
    io:format(user, "Decide if we have reaction events~n", []),
    io:format(user, "====================================~n", []),

    case {Function, ActionEvent2, ReactionEvents} of
        _NoActionEvent = {_, {[], _, _}, _} ->
            io:format(user, "No action event for ~p:~p/~p~n", [Module, Function, 1]),
            write_no_events(ApiFun),
            {Events, AttemptTypeIndexes2, PropertyTypes};
        _NoReactionEvent = {attempt, _, [undefined]} ->
            io:format(user, "No reaction events for ~p:~p/~p~n", [Module, Function, 1]),
            write_no_events(ApiFun),
            {Events, AttemptTypeIndexes2, PropertyTypes};
        _ ->
            io:format(user, "Adding new action->reaction pairs~n", []),
            io:format(user, "Action Event: ~p~n", [ActionEvent2]),
            io:format(user, "Reaction Events: ~p~n", [ReactionEvents]),
            NewEvents = [[Module, Function, ActionEvent2, ReactionEvent] || ReactionEvent <- ReactionEvents],
            {Events ++ NewEvents, AttemptTypeIndexes2, PropertyTypes}
    end;
get_event_pairs({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}, Acc) ->
    Acc.

maybe_add_attempt_types(IndexedEvent, EventTypeIndex, AttemptTypeIndexes) ->
    case AttemptTypeIndexes of
        #{IndexedEvent := EventTypeIndex} ->
            AttemptTypeIndexes;
        % I'm guessing that if we have multiple attempt events with the same shape,
        % but different types, then we can't infer what types a success event with the same
        % shape will have
        #{IndexedEvent := _ConflictingTypeIndex} ->
            _EventsWithOnlyOnePossibleTypeIndex = maps:remove(IndexedEvent, AttemptTypeIndexes);
        _ ->
            AttemptTypeIndexes#{IndexedEvent => EventTypeIndex}
    end.

merge_type_indexes(TypeIndex1, TypeIndex2) ->
    Map1 = maps:from_list(TypeIndex1),
    Map2 = maps:from_list(TypeIndex2),
    maps:to_list(maps:merge(Map1, Map2)).

write_no_events(ApiFun) ->
    %io:format(user, "NO EVENTS:~nApiFun = ~p~n", [ApiFun]),
    {ok, IO} = file:open("no_events", [write, append]),
    file:write(IO, io_lib:format("~p~n", [ApiFun])),
    ok = file:close(IO).

event(attempt, [{match, _, {tuple, [_, _, {var, Event}, _]}}]) ->
    maybe_var_event(Event);
event(attempt, [{tuple, [_, _, Event, _]}]) ->
    Event;
event(succeed, [{tuple, [_, {var, Event}, _]}]) ->
    maybe_var_event(Event);
event(succeed, [{tuple, [_Props, Event, _Context]}]) ->
    Event.

maybe_var_event(Event) ->
    case atom_to_list(Event) of
        [$_ | _] ->
            {var, '_'};
        _ ->
            {var, Event}
    end.

reaction_events({call,
                 {remote,
                  {atom, egre},
                  {atom, attempt}},
                 [_Target,
                  Event | _MaybeSub]},
                State = #state{events = Events}) ->
    ReactionEvent = ?INDEX:index_event(Event, State),
    State#state{events = [ReactionEvent | Events]};
reaction_events({call,
                 {remote,
                  {atom, egre},
                  {atom, attempt_after}},
                 [_TickTime,
                  _Target,
                  Event]},
                State = #state{events = Events}) ->
    ReactionEvent = ?INDEX:index_event(Event, State),
    State#state{events = [ReactionEvent | Events]};
reaction_events({record, result, RecordFields},
                State) ->
    maybe_result_record_event(RecordFields, State);
reaction_events(Match = {match, {var, Var1}, {var, Var2}},
                State = #state{variables = Variables,
                               type_map = TypeMap}) ->
    Variables2 =
        case Variables of
            #{Var2 := Value} ->
                Variables#{Var1 => Value};
            _ ->
                Variables#{Var1 => Var2}
        end,

    TypeMap2 = ?GUARDS:infer(Match, TypeMap),
    State#state{variables = Variables2,
                type_map = TypeMap2};
% TODO consider other cases where a bare '+' might occur,
% such as a case expression:
% case A + B of X ... end
reaction_events({match, {var, Var3}, {op, Op, {var, Var1}, {var, Var2}}},
                State = #state{type_map = TypeMap})
  when Op == '+';
       Op == '-' ->
    State#state{type_map = TypeMap#{Var1 => integer,
                                    Var2 => integer,
                                    Var3 => integer}};
reaction_events({match, {var, Var}, Value = {tuple, _}},
                State = #state{variables = Variables}) ->
    % TODO recurse through the assignment, e.g. when assigning from a
    % case statement (e.g. an inlined function call, or remote call)
    %
    % e.g. [{1, <<"Character">>}, {2, <<"proplists:get_value(a, List)">>}]
    State#state{variables = Variables#{Var => Value}};
reaction_events({match, {var, Var},
                 Case = {'case', _, [{clause, _, _, ClauseExprs}]}},
                State = #state{variables = Variables}) ->
    State2 = reaction_events(Case, State),
    LastClauseExpr = lists:last(ClauseExprs),
    Variables2 = Variables#{Var => LastClauseExpr},
    State2#state{variables = Variables2};
reaction_events({match, {var, Var},
                 {call,
                  {remote, {atom, 'proplists'}, {atom, 'get_value'}},
                  [_, _, {integer, _}]}},
                State = #state{type_map = TypeMap}) ->
    State#state{type_map = TypeMap#{Var => integer}};
reaction_events({op, Op, {var, Var1}, {var, Var2}},
                State = #state{type_map = TypeMap})
  when Op == '+';
       Op == '-' ->
    State#state{type_map = TypeMap#{Var1 => integer,
                                    Var2 => integer}};
reaction_events(Form, State) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    reaction_events(List, State);
reaction_events(Forms, State) when is_list(Forms) ->
    lists:foldl(fun reaction_events/2,
                State,
                Forms);
reaction_events(_Form, State) ->
    %ct:pal("~p:~p: _Form~n\t~p~n\t~p~n", [?MODULE, ?FUNCTION_NAME, _Form, State]),
    State.

maybe_result_record_event(RecordFields, State) ->
    lists:foldl(fun maybe_result_record_field_event/2, State, RecordFields).

maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, resend}, _Target, Event]}},
                                State = #state{events = Events}) ->
    % State#state{events = [indexed_event(Event, State) | Events]};

    State2 = State#state{events = [?INDEX:index_event(Event, State) | Events]},
    io:format(user, "maybe_result_record_field_event new state:~n~p~n", [State2]),
    State2;
maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, broadcast}, Event]}},
                                State = #state{events = Events}) ->
    State#state{events = [?INDEX:index_event(Event, State) | Events]};
maybe_result_record_field_event({record_field,
                                 {atom, event},
                                 Event = {TupleOrVar, _}},
                                State = #state{events = Events})
  when TupleOrVar == tuple;
       TupleOrVar == var ->
    State#state{events = [?INDEX:index_event(Event, State) | Events]};
maybe_result_record_field_event(_, State) ->
    State.

% {match,{var,'_Active'},{cons,{var,'_'},{var,'_'}}}

%{match,{var,'_Phrase'},
       %{bin,[{bin_element,{string,"quest "},default,default},
             %{bin_element,{var,'QuestName'},default,[binary]}]}}

