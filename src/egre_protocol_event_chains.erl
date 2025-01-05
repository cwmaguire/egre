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
    lists:filtermap(fun get_event/1, FunClauses).

write_events(_) ->
    ok.

flatten_clauses({K, Clauses}, ModuleClauses) ->
    ModuleClausesNew = [{K, Clause} || Clause <- Clauses],
    ModuleClauses ++ ModuleClausesNew.

get_event({_K, {clause, [{var, '_'}], _, _}}) ->
    false;
get_event({{Module, Function, ?API_FUNCTION_ARITY}, {clause, Arguments, _Guards, _Body}}) ->
    [{tuple, [_CustomData, _Props, Event, _Context]}] = Arguments,
    {IndexedEvent, IndexedVariables} = indexed_event(Event),
    {true, [Module, Function, IndexedEvent, _TypeInf = [], IndexedVariables, undefined, undefined, undefined]};
get_event({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}) ->
    false.

indexed_event({tuple, Event}) ->
    {_, IndexedEvent, IndexedVariables} =
        lists:foldl(fun a/2, {1, [], []}, Event),
    IndexedEventTuple = list_to_tuple(IndexedEvent),
    {IndexedEventTuple, IndexedVariables}.

a({var, Var}, {Index, Event, IndexedVariables}) ->
    {Index + 1, Event ++ [Index], IndexedVariables ++ [{Index, atom_to_binary(Var)}]};
a({atom, Atom}, {Index, Event, IndexedVariables}) ->
    {Index, Event ++ [Atom], IndexedVariables}.
