%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_event_parsing_SUITE).

-include("egre_protocol_event_parsing.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([all/0]).

-export([no_events/1]).
-export([terminal_event/1]).
-export([action_reaction/1]).
-export([resend_raw_event/1]).
-export([resend_variable_event/1]).
-export([modify_raw_event/1]).
-export([broadcast_raw_event/1]).
-export([type_inference/1]).

all() ->
    [no_events,
     terminal_event,
     action_reaction,
     resend_raw_event,
     resend_variable_event,
     modify_raw_event,
     broadcast_raw_event,
     type_inference].

no_events(_Config) ->
    Events = egre_protocol_event_chains:get_events(?NO_EVENTS),
    ?assertEqual([], Events).

terminal_event(_Config) ->
    Events = egre_protocol_event_chains:get_events(?TERMINAL_EVENT),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, attack, 2, with, 3},
                        [{1, <<"Character">>}, {2, <<"Target">>}, {3, <<"Owner">>}],
                        _ActionTypeInference = []},

                       %% Reaction event
                       {undefined, undefined, undefined}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

action_reaction(_Config) ->
    Events = egre_protocol_event_chains:get_events(?ACTION_REACTION),
    SortedEvents = lists:sort(Events),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, attack, 2, with, 3},
                        [{1, <<"Character">>}, {2, <<"Target">>}, {3, <<"Owner">>}],
                        _ActionTypeInference2 = []},

                       %% Reaction event
                       {{1, make_noise},
                        [{1, <<"Animal">>}],
                        _ReactionTypeInference2 = []}
                      ],
                      [<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, attack, 2, with, 3},
                        [{1, <<"Character">>}, {2, <<"Target">>}, {3, <<"Owner">>}],
                        _ActionTypeInference1 = []},

                       %% Reaction event
                       {{1, unreserve, 2, for, 3},
                        [{1, <<"Character">>}, {2, <<"Resource">>}, {3, <<"Owner">>}],
                        _ReactionTypeInference1 = []}
                      ]
                     ],
    ?assertEqual(ExpectedEvents, SortedEvents).

resend_raw_event(_Config) ->
    expect_event(?RESEND_RAW_EVENT).

resend_variable_event(_Config) ->
    expect_event(?RESEND_VARIABLE_EVENT).

modify_raw_event(_Config) ->
    expect_event(?MODIFY_RAW_EVENT).

broadcast_raw_event(_Config) ->
    expect_event(?BROADCAST_RAW_EVENT).

expect_event(ApiFunctionClauses) ->
    Events = egre_protocol_event_chains:get_events(ApiFunctionClauses),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, attack, 2, with, 3},
                        [{1, <<"Character">>}, {2, <<"Target">>}, {3, <<"Owner">>}],
                        _ActionTypeInference = []},

                       %% Reaction event
                       {{1, go, 2},
                        [{1, <<"Character">>}, {2, <<"Direction">>}],
                        _ReactionTypeInference = []}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference(_Config) ->
    Events = egre_protocol_event_chains:get_events(?TYPE_INFERENCE),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, abc, 2, def, 3},
                        [{1, <<"Pid1">>}, {2, <<"Pid2">>}, {3, <<"NotPid">>}],
                        [{2, pid}, {1, pid}]},

                       %% Reaction event
                       {{1, ghi, 2, 3},
                        [{1, <<"Pid1">>}, {2, <<"Pid3">>}, {3, <<"NotPid">>}],
                        [{1, pid}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

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
