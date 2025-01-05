%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_event_parsing_SUITE).

-include("egre_protocol_event_parsing.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([all/0]).

-export([no_events/1]).
-export([terminal_event/1]).

all() ->
    [no_events,
     terminal_event].

no_events(_Config) ->
    Events = egre_protocol_event_chains:get_events(?NO_EVENTS),
    ?assertEqual([], Events).

% - parent 1
%   - child 1 / parent 2
%     - child 2

% What do we need to write in the BERT file to make chains:
% - module
% - event type (attempt / succeed)
% - event tuple (e.g. {foo, 1, baz, 2})
% - indexed variables (e.g. [{1, <<"Bar">>}, {2, <<"Quux">>}])
% - type inference

% {attack, <<"bob">>}         -> {attack, <0.1.0>}
% {attack, 1}, [{1, binary}]  -> {attack, 1}, [{1, pid}]

terminal_event(_Config) ->
    Events = egre_protocol_event_chains:get_events(?TERMINAL_EVENT),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {1, attack, 2, with, 3},
                       _ActionTypeInference = [],
                       [{1, <<"Character">>}, {2, <<"Target">>}, {3, <<"Owner">>}],

                       %% Reaction event
                       undefined,
                       undefined,
                       undefined
                      ]],
    ?assertEqual(ExpectedEvents, Events).
