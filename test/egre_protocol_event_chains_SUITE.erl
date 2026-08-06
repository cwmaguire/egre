-module(egre_protocol_event_chains_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include("egre_protocol_event_chains.hrl").

-export([all/0]).

-export([single_chain_head/1]).
-export([no_cycles/1]).
-export([one_pair_chain/1]).
-export([two_pair_chain/1]).
-export([three_pair_chain/1]).
-export([no_loop/1]).
-export([two_chains/1]).
-export([pairs_match/1]).
-export([only_one_chain_head/1]).

-define(CHAINS, egre_protocol_event_chains).

all() ->
    [single_chain_head,
     no_cycles,
     one_pair_chain,
     two_pair_chain,
     three_pair_chain,
     no_loop,
     two_chains,
     pairs_match,
     only_one_chain_head].

single_chain_head(_Config) ->
    ChainHeads = ?CHAINS:chain_heads(?SINGLE_PAIR),
    ?assertEqual([?SINGLE_PAIR], ChainHeads).

no_cycles(_Config) ->
    Chains = ?CHAINS:make_chains(?NO_CYCLES),
    ?assertEqual([?NO_CYCLES], Chains).

one_pair_chain(_Config) ->
    Chains = ?CHAINS:make_chains(?SINGLE_PAIR),
    ?assertEqual([?SINGLE_PAIR], Chains).

two_pair_chain(_Config) ->
    Chains = ?CHAINS:make_chains(?TWO_PAIR_CHAIN),
    ?assertEqual([?TWO_PAIR_CHAIN], Chains).

three_pair_chain(_Config) ->
    Chains = ?CHAINS:make_chains(?THREE_PAIR_CHAIN),
    ?assertEqual([?THREE_PAIR_CHAIN], Chains).

no_loop(_Config) ->
    Chains = ?CHAINS:make_chains(?LOOP_CHAIN),
    ?assertEqual([?LOOP_CHAIN], Chains).

two_chains(_Config) ->
    [ChainOne, ChainTwo] = ?CHAINS:make_chains(?TWO_CHAINS),
    ?assertEqual(?TWO_CHAINS_ONE, ChainOne),
    ?assertEqual(?TWO_CHAINS_TWO, ChainTwo).

pairs_match(_Config) ->
    [P1, P2] = ?TWO_PAIR_CHAIN,
    ?assert(?CHAINS:is_pair_match([], P1, P2)).

only_one_chain_head(_Config) ->
    [P1, _] = ?TWO_PAIR_CHAIN,
    ChainHeads = (?CHAINS:chain_heads(?TWO_PAIR_CHAIN)),
    ?assertEqual([[P1]], ChainHeads).

%% two pair chain that's a cycle: a->b,b->a
%% We need to know it exists, but have it stop
