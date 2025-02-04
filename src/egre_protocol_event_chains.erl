-module(egre_protocol_event_chains).

-export([chains/0]).

chains() ->
    egre_dbg:add(egre_protocol_event_chains, chains_),
    Data = read_data(),
    io:format(user, "Data = ~p~n", [Data]),
    ReactionEvents = [{E, Types} || {_, _, _, {E, _, Types}} <- Data],
    %io:format(user, "ReactionEvents = ~p~n", [ReactionEvents]),
    Chains0 = [[Pair] || Pair = {_, _, {E, _, Types}, _} <- Data,
                          not lists:member({E, Types}, ReactionEvents)],
    %io:format(user, "Chains0 = ~p~n", [Chains0]),
    Chains = chains_(Chains0, _DeadChains = [], Data),
    [print(Chain) || Chain <- Chains],
    io:format(user, "Chains = ~p~n", [Chains]).

read_data() ->
    filelib:fold_files("events", ~S".*\.bert", false, fun read_file/2, _Data = []).

read_file(Filename, Pairs) ->
    {ok, Binary} = file:read_file(Filename, [read]),
    PairList = binary_to_term(Binary),
    io:format(user, "Term = ~p~n", [PairList]),
    Pairs ++ [list_to_tuple(P) || P <- PairList].

chains_(_Live = [], Dead, _Data) ->
    Dead;
chains_([C = [{_, _, _, undefined} | _] | Live], Dead, Data) ->
    chains_(Live, [lists:reverse(C) | Dead], Data);
chains_([C = [{_, _, _, {E, _, Ts}} | _] | Live], Dead, Data) ->
    LinkedPairs = [P || P = {_, _, {E2, _, Ts2}, _} <- Data,
                        E == E2, Ts == Ts2],
    case LinkedPairs of
        [] ->
            chains_(Live, [lists:reverse(C) | Dead], Data);
        _ ->
            NewChains = [[N | C] || N <- LinkedPairs],
            chains_(NewChains ++ Live, Dead, Data)
    end.

print(Chain) ->
    print(Chain, _Indent = <<>>).

print([], _) ->
    ok;
print([Pair | Rest], Indent) ->
    Bin = serialize(Pair),
    Output = <<Indent/binary, Bin/binary>>,
    io:format("~p~n", [Output]),
    print(Rest, <<Indent/binary, "  ">>).

serialize({Mod, Fun, {AE, AV, AT}, {RE, RV, RT}}) ->
    % TODO actually serialize this stuff
    <<"">>.
