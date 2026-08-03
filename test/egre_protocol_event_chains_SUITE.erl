-module(egre_protocol_event_chains_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include("egre_protocol_event_chains.hrl").

-export([all/0]).

-export([single_chain_head/1]).
-export([no_cycles/1]).


all() ->
    [single_chain_head,
     no_cycles].

single_chain_head(_Config) ->
    ChainHeads = egre_protocol_event_chains:chain_heads(?SINGLE_PAIR),
    ?assertEqual([?SINGLE_PAIR], ChainHeads).

no_cycles(_Config) ->
    Chains = egre_protocol_event_chains:make_chains(?NO_CYCLES),
    ?assertEqual([?NO_CYCLES], Chains).
