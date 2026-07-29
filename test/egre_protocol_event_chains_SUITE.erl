-module(egre_protocol_event_chains_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include("egre_protocol_event_chains.hrl").

-export([all/0]).

-export([no_cycles/1]).


all() ->
    [no_cycles].

no_cycles(_Config) ->
    Chains = egre_protocol_event_chains:make_chains(?NO_CYCLES),
    ?assertEqual([], Chains).
