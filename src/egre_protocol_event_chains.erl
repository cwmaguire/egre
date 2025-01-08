-module(egre_protocol_event_chains).

-export([extract/1]).
-export([get_events/1]).
-export([write_events/1]).

-define(API_FUNCTION_ARITY, 1).


extract(ApiFuns) ->
  Events = get_events(ApiFuns),
  write_events(Events).

get_events(ApiFuns) ->
    FunClauses = lists:foldl(fun flatten_clauses/2, [], ApiFuns),
    lists:foldl(fun get_event_pairs/2, [], FunClauses).

write_events(_) ->
    ok.

flatten_clauses({K, Clauses}, ModuleClauses) ->
    ModuleClausesNew = [{K, Clause} || Clause <- Clauses],
    ModuleClauses ++ ModuleClausesNew.

get_event_pairs({_K, {clause, [{var, '_'}], _, _}}, Events) ->
    Events;
get_event_pairs({{Module, attempt, ?API_FUNCTION_ARITY}, {clause, Arguments, _Guards, Body}},
          Events) ->
    [{tuple, [_CustomData, _Props, Event, _Context]}] = Arguments,
    {IndexedEvent, IndexedVariables} = indexed_event(Event),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},

    EventsVars = {_Events = [], _Variables = #{}},
    ReactionEvents =
        case lists:foldl(fun reaction_events/2, EventsVars, Body) of
            {[], _} ->
                [{undefined, undefined, undefined}];
            {List, _} ->
                List
        end,

    NewEvents = [[Module, attempt, ActionEvent, ReactionEvent] || ReactionEvent <- ReactionEvents],
    Events ++ NewEvents;
get_event_pairs({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}, Events) ->
    Events.

reaction_events({call,
                 {remote,
                  {atom, egre},
                  {atom, attempt}},
                 [_Target,
                  Event | _MaybeSub]},
                {Events, Variables}) ->
    % TODO replace variable arguments with values from Variables map
    {IndexedEvent, IndexedVariables} = indexed_event(Event),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},
    {[ActionEvent | Events], Variables};
reaction_events({record, result, RecordFields},
                EventsVars) ->
    ct:pal("~p:~p: RecordFields~n\t~p~n", [?MODULE, ?FUNCTION_NAME, RecordFields]),
    maybe_result_record_event(RecordFields, EventsVars);
reaction_events({match, {var, Var}, Value},
                {Events, Variables}) ->
    % TODO recurse through the assignment, e.g. when assigning from a
    % case statement (e.g. an inlined function call, or remote call)
    %
    % e.g. [{1, <<"Character">>}, {2, <<"proplists:get_value(a, List)">>}]
    {Events, Variables#{Var => Value}};
reaction_events(Form, EventsVars) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    reaction_events(List, EventsVars);
reaction_events(Forms, EventsVars) when is_list(Forms) ->
    lists:foldl(fun reaction_events/2,
                EventsVars,
                Forms);
reaction_events(_Form, EventsVars) ->
    ct:pal("~p:~p: _Form~n\t~p~n\t~p~n", [?MODULE, ?FUNCTION_NAME, _Form, EventsVars]),
    EventsVars.

maybe_result_record_event(RecordFields, EventsVars) ->
    lists:foldl(fun maybe_result_record_field_event/2, EventsVars, RecordFields).

maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, resend}, _Target, Event]}},
                                {Events, Variables}) ->
    {IndexedEvent, IndexedVariables} = indexed_event(Event, Variables),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},
    {[ActionEvent | Events], Variables};
maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, broadcast}, Event]}},
                                {Events, Variables}) ->
    {IndexedEvent, IndexedVariables} = indexed_event(Event, Variables),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},
    {[ActionEvent | Events], Variables};
maybe_result_record_field_event({record_field,
                                 {atom, event},
                                 Event = {tuple, _}},
                                {Events, Variables}) ->
    {IndexedEvent, IndexedVariables} = indexed_event(Event, Variables),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},
    {[ActionEvent | Events], Variables};
maybe_result_record_field_event(_, EventsVars) ->
    EventsVars.

indexed_event(Event) ->
    indexed_event(Event, _Variables = #{}).

indexed_event({var, EventVar}, Variables) ->
    #{EventVar := Event} = Variables,
    indexed_event(Event, Variables);
indexed_event({tuple, Event}, _) ->
    {_, IndexedEvent, IndexedVariables} =
        lists:foldl(fun index_variable/2, {1, [], []}, Event),
    IndexedEventTuple = list_to_tuple(IndexedEvent),
    {IndexedEventTuple, IndexedVariables}.

index_variable({var, Var}, {Index, Event, IndexedVariables}) ->
    {Index + 1, Event ++ [Index], IndexedVariables ++ [{Index, atom_to_binary(Var)}]};
index_variable({atom, Atom}, {Index, Event, IndexedVariables}) ->
    {Index, Event ++ [Atom], IndexedVariables}.
