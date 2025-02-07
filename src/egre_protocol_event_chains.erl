-module(egre_protocol_event_chains).

-export([chains/0]).

-define(INDENT, "  ").
-define(INFINITE_LOOP, [_Tail = {_Mod, _Fun, _ActionEvent = {E, _, Ts}, _ReactionEvent = {E, _, Ts}} | _]).
-define(DEAD_END, [{_, _, _, undefined} | _]).

chains() ->
    %egre_dbg:add(egre_protocol_event_chains, serialize),
    Pairs = read_pairs(),
    write_pairs(Pairs),
    ChainHeads = chain_heads(Pairs),
    Chains = chains_(ChainHeads, _DeadChains = [], Pairs),
    [print(Chain) || Chain <- Chains].
    %io:format(user, "Chains = ~p~n", [Chains]).

chain_heads(Data) ->
    ReactionEvents = [{E, Types} || {_, _, _, {E, _, Types}} <- Data],
    [[Pair] || Pair = {_, _, {E, _, Types}, {_, _, _}} <- Data,
               not lists:member({E, Types}, ReactionEvents)].

read_pairs() ->
    filelib:fold_files("events", ~S".*\.bert$", false, fun read_file/2, _Data = []).

read_file(Filename, Pairs) ->
    {ok, Binary} = file:read_file(Filename, [read]),
    PairList = binary_to_term(Binary),
    %io:format(user, "Term = ~p~n", [PairList]),
    Pairs ++ [list_to_tuple(P) || P <- PairList].

write_pairs(Pairs) ->
    {ok, IO} = file:open("pairs", [write]),
    [write_pair(P, IO) || P <- Pairs],
    ok = file:close(IO).

write_pair(Pair, IO) ->
    Chars = io_lib:format("~p~n", [Pair]),
    file:write(IO, Chars).

chains_(_Live = [], Dead, _Data) ->
    Dead;
chains_([C = ?DEAD_END | Live], Dead, Data) ->
    chains_(Live, [lists:reverse(C) | Dead], Data);
%% TODO what if the ONLY action-reaction is a loop? (e.g. rules_resources_tick.erl)
chains_([C = ?INFINITE_LOOP | Live], Dead, Data) ->
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
    {ok, IO} = file:open("egre_protocol_chains", [write]),
    print(Chain, IO, _Indent = <<>>),
    ok = file:close(IO).

print([], _, _) ->
    ok;
print([Pair | Rest], IO, Indent) ->
    IoList = serialize_pair(Pair, Indent),
    Output = [Indent, IoList, <<"\n">>],
    %io:format("~w~n", [Output]),
    file:write(IO, Output),
    print(Rest, IO, increase_indent(Indent)).

increase_indent(Indent) ->
    <<Indent/binary, ?INDENT>>.

serialize_pair({Mod, Fun, AE, RE}, Indent) ->
    FunBin = atom_to_binary(Fun),
    {ActionBin, ActionVars} = serialize_event(AE),
    {ReactionBin, ReactionVars} = serialize_event(RE),
    SpaceSize = 1,
    ColonSize = 1,
    NextIndent = [Indent, <<?INDENT>>],
    Padding = list_to_binary(string:pad("", size(Mod) + ColonSize + size(FunBin) + SpaceSize)),
    [FunBin, <<":">>, Mod, <<" ">>,
     ActionBin, <<" ->                  ">> , ActionVars, <<"\n">>,
     NextIndent, Padding,
     ReactionBin,  <<"                  ">>, ReactionVars].

serialize_event(undefined) ->
    {<<"no reaction">>, <<"">>};
serialize_event({Event, Vars, Types}) ->
    EventBins = [to_bin(E) || E <- tuple_to_list(Event)],
    %EventBin = [<<"{">>, lists:join(<<" ">>, EventBins), <<"}">>],
    EventBin = lists:join(<<" ">>, EventBins),
    VarBins = [[to_bin(Idx), <<":">>, V] || {Idx, V} <- Vars],
    VarBin = lists:join(<<", ">>, VarBins),
    TypeBins = [to_bin(T) || {_I, T} <- Types],
    TypeBin =
        case TypeBins of
            [] ->
                <<" (No Types)">>;
            _ ->
                [<<" [">>, lists:join(<<" ">>, TypeBins), <<"]">>]
        end,
    {[<<"{">>, EventBin, <<", ">>, TypeBin, <<"}">>], VarBin}.

to_bin(I) when is_integer(I) ->
    integer_to_binary(I);
to_bin(A) when is_atom(A) ->
    atom_to_binary(A);
to_bin(T) when is_tuple(T) ->
    [<<"{">>, [to_bin(E) || E <- tuple_to_list(T)], <<"}">>].
