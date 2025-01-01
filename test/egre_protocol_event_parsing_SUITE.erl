%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_event_parsing_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([all/0]).

-export([no_events/1]).

all() ->
    [no_events].

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

no_events(_Config) ->
    Events = egre_protocol_event_chains:get_events(?NO_EVENTS),
    ?assertEqual([], Events).
