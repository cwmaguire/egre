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
-export([type_inference_self/1]).
-export([type_inference_is_pid/1]).
-export([type_inference_is_binary/1]).
-export([type_inference_equals/1]).
-export([type_inference_plus/1]).
-export([type_inference_recursive/1]).
-export([type_inference_event_plus/1]).
-export([type_inference_andalso/1]).
-export([props_inference_match/1]).
-export([props_inference_egre_object_has_pid/1]).
-export([props_inference_new_var/1]).

all() ->
    [no_events,
     terminal_event,
     action_reaction,
     resend_raw_event,
     resend_variable_event,
     modify_raw_event,
     broadcast_raw_event,
     type_inference_self,
     type_inference_is_pid,
     type_inference_is_binary,
     type_inference_equals,
     type_inference_plus,
     type_inference_event_plus,
     type_inference_recursive,
     props_inference_match,
     props_inference_egre_object_has_pid,
     props_inference_new_var].

% all() ->
%     [type_inference_prop_match].

no_events(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?NO_EVENTS),
    ?assertEqual([], Events).

terminal_event(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TERMINAL_EVENT),
    ExpectedEvents = [],
    ?assertEqual(ExpectedEvents, Events).

action_reaction(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?ACTION_REACTION),
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
    % egre_dbg:add(egre_protocol_event_pairs, reaction_events),
    expect_event(?RESEND_VARIABLE_EVENT).

modify_raw_event(_Config) ->
    expect_event(?MODIFY_RAW_EVENT).

broadcast_raw_event(_Config) ->
    expect_event(?BROADCAST_RAW_EVENT).

expect_event(ApiFunctionClauses) ->
    Events = egre_protocol_event_pairs:get_events(ApiFunctionClauses),
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

type_inference_self(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_SELF),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, abc, 2, def, 3},
                        [{1, <<"Pid1">>}, {2, <<"Pid2">>}, {3, <<"NotPid">>}],
                        [{1, pid}, {2, pid}]},

                       %% Reaction event
                       {{1, ghi, 2, 3},
                        [{1, <<"Pid1">>}, {2, <<"Pid3">>}, {3, <<"NotPid">>}],
                        [{1, pid}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_is_pid(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_IS_PID),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1},
                        [{1, <<"Pid1">>}],
                        [{1, pid}]},

                       %% Reaction event
                       {{1, 2},
                        [{1, <<"Pid1">>}, {2, <<"NotPid">>}],
                        [{1, pid}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_is_binary(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_IS_BINARY),
    ExpectedEvents = [[<<"look">>,
                       attempt,

                       %% Action event
                       {{1},
                        [{1, <<"TargetName">>}],
                        [{1, binary}]},

                       %% Reaction event
                       {{1},
                        [{1, <<"TargetName">>}],
                        [{1, binary}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_equals(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_EQUALS),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, 2, 3, 4, 5},
                        [{1, <<"Atom1">>},
                         {2, <<"Int1">>},
                         {3, <<"Float1">>},
                         {4, <<"Char1">>},
                         {5, <<"EmptyList1">>}],
                        [{1, atom},
                         {2, integer},
                         {3, float},
                         {4, char},
                         {5, list}]},

                       %% Reaction event
                       {{1, 2, 3, 4, 5},
                        [{1, <<"Atom2">>},
                         {2, <<"Int2">>},
                         {3, <<"Float2">>},
                         {4, <<"Char2">>},
                         {5, <<"EmptyList2">>}],
                        [{1, atom},
                         {2, integer},
                         {3, float},
                         {4, char},
                         {5, list}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_plus(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_PLUS),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Num2">>}],
                        [{1, integer},
                         {2, integer}]},

                       %% Reaction event
                       {{1},
                        [{1, <<"Num3">>}],
                        [{1, integer}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_event_plus(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_EVENT_PLUS),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{foo},
                        [],
                        []},

                       %% Reaction event
                       {{do, 1},
                        [{1, <<"(Num1 + Num2)">>}],
                        [{1, integer}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_recursive(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_RECURSIVE),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Num2">>}],
                        [{1, integer},
                         {2, integer}]},

                       %% Reaction event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Num2">>}],
                        [{1, integer},
                         {2, integer}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

type_inference_andalso(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?TYPE_INFERENCE_ANDALSO),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Atom1">>}],
                        [{1, integer},
                         {2, atom}]},

                       %% Reaction event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Atom1">>}],
                        [{1, integer},
                         {2, atom}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

props_inference_match(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?PROPS_INFERENCE_MATCH, #{owner => pid}),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Atom1">>}],
                        []},

                       %% Reaction event
                       {{1, 2},
                        [{1, <<"Owner">>},
                         {2, <<"Atom1">>}],
                        [{1, pid}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).

props_inference_egre_object_has_pid(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?PROPS_INFERENCE_EGRE_OBJECT_HAS_PID,
                                                  #{owner => pid}),
    ExpectedEvents = [[<<"char_inv">>,
                       attempt,

                       %% Action event
                       {{1, 2, 3},
                        [{1, <<"Self">>},
                         {2, <<"Action">>},
                         {3, <<"Item">>}],
                        [{3, pid}]},

                       %% Reaction event
                       {{1, move, from, 2, to, 3},
                        [{1, <<"Item">>},
                         {2, <<"Source">>},
                         {3, <<"Target">>}],
                        [{1, pid}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).


props_inference_new_var(_Config) ->
    Events = egre_protocol_event_pairs:get_events(?PROPS_INFERENCE_NEW_VAR, #{owner => pid}),
    ExpectedEvents = [[<<"attack_resource">>,
                       attempt,

                       %% Action event
                       {{1, 2},
                        [{1, <<"Num1">>},
                         {2, <<"Atom1">>}],
                        []},

                       %% Reaction event
                       {{1, 2},
                        [{1, <<"Owner">>},
                         {2, <<"Atom1">>}],
                        [{1, pid}]}
                      ]],
    ?assertEqual(ExpectedEvents, Events).
