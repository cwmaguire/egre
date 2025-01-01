-module(egre_protocol_event_chains).

-export([extract/1]).
-export([get_events/1]).
-export([write_events/1]).

-define(NO_EVENTS,
        [{{module_1, attempt, 1},
          [{clause,
            [{var,'_'}],
            [],
            [{'case',
              {tuple,[]},
              [{clause,
                [{tuple,[]}],
                [],
                [{'case',
                  {tuple,[]},
                  [{clause,
                    [{tuple,[]}],
                    [],
                    [{tuple,[{atom,return},{atom,ok}]}]}]}]}]}]}]}]).

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
get_event({{_Module, _Function, _Arity}, {clause, _Bindings, _Guards, _Body}}) ->
    {true, ok}.
