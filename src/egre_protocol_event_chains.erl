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
    %lists:filtermap(fun get_event/1, FunClauses).
    lists:foldl(fun get_event/2, [], FunClauses).

write_events(_) ->
    ok.

flatten_clauses({K, Clauses}, ModuleClauses) ->
    ModuleClausesNew = [{K, Clause} || Clause <- Clauses],
    ModuleClauses ++ ModuleClausesNew.

get_event({_K, {clause, [{var, '_'}], _, _}}, Events) ->
    Events;
get_event({{Module, attempt, ?API_FUNCTION_ARITY}, {clause, Arguments, _Guards, Body}},
          Events) ->
    [{tuple, [_CustomData, _Props, Event, _Context]}] = Arguments,
    {IndexedEvent, IndexedVariables} = indexed_event(Event),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},

    ReactionEvents =
        case lists:foldl(fun reaction_events/2, [], Body) of
            [] ->
                [{undefined, undefined, undefined}];
            List ->
                List
        end,

    NewEvents = [[Module, attempt, ActionEvent, ReactionEvent] || ReactionEvent <- ReactionEvents],
    Events ++ NewEvents;
get_event({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}, Events) ->
    Events.

indexed_event({tuple, Event}) ->
    {_, IndexedEvent, IndexedVariables} =
        lists:foldl(fun a/2, {1, [], []}, Event),
    IndexedEventTuple = list_to_tuple(IndexedEvent),
    {IndexedEventTuple, IndexedVariables}.

a({var, Var}, {Index, Event, IndexedVariables}) ->
    {Index + 1, Event ++ [Index], IndexedVariables ++ [{Index, atom_to_binary(Var)}]};
a({atom, Atom}, {Index, Event, IndexedVariables}) ->
    {Index, Event ++ [Atom], IndexedVariables}.

reaction_events({call,
                 {remote,
                  {atom, egre_object},
                  {atom, attempt}},
                 [_Target,
                  Arguments]},
                Events) ->
    {IndexedEvent, IndexedVariables} = indexed_event(Arguments),
    ActionEvent = {IndexedEvent, _TypeInf = [], IndexedVariables},
    [ActionEvent | Events];
reaction_events(Form, Events) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    reaction_events(List, Events);
reaction_events(Form, Events) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    lists:foldl(fun reaction_events/2,
                Events,
                List).
