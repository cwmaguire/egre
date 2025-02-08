-module(egre_protocol_event_chains).

-export([chains/0]).

-define(INDENT, "  ").
-define(INFINITE_LOOP, [_Tail = {_Mod, _Fun, _ActionEvent = {E, _, Ts}, _ReactionEvent = {E, _, Ts}} | _]).
-define(DEAD_END, [{_, _, _, undefined} | _]).

chains() ->
    %egre_dbg:add(egre_protocol_event_chains, serialize),
    Pairs0 = read_pairs(),
    Pairs = normalize_types(Pairs0),
    write_pairs(Pairs),
    ChainHeads = chain_heads(Pairs),
    io:format(user, "ChainHeads = ~p~n", [ChainHeads]),
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

normalize_types(Pairs) ->
    [normalize_pair_types(P) || P <- Pairs].

normalize_pair_types({M, F, ActionEvent, ReactionEvent}) ->
    {M,
     F,
     normalize_event_types(ActionEvent),
     normalize_event_types(ReactionEvent)}.

normalize_event_types(undefined) ->
    undefined;
normalize_event_types({Event, Vars, Types}) ->
    EventList = tuple_to_list(Event),
    Types2 = normalize_event_types(EventList, Types, _Normalized = []),
    {Event, Vars, Types2}.

normalize_event_types([], _, Normalized) ->
    lists:reverse(Normalized);
normalize_event_types([Index | Event], [{Index, Type} | Types], Normalized) ->
    normalize_event_types(Event, Types, [Type | Normalized]);
normalize_event_types([Index | Event], Types, Normalized) when is_integer(Index) ->
    normalize_event_types(Event, Types, ['_' | Normalized]);
normalize_event_types([_Atom | Event], Types, Normalized) ->
    normalize_event_types(Event, Types, Normalized).

write_pairs(Pairs) ->
    {ok, IO} = file:open("pairs", [write]),
    [write_pair(P, IO) || P <- Pairs],
    ok = file:close(IO).

write_pair(Pair, IO) ->
    Chars = io_lib:format("~p~n", [Pair]),
    file:write(IO, Chars).

chains_(_Live = [], Dead, _AllPairs) ->
    Dead;
chains_([C = ?DEAD_END | Live], Dead,  AllPairs) ->
    chains_(Live, [lists:reverse(C) | Dead],  AllPairs);
%% TODO what if the ONLY action-reaction is a loop? (e.g. rules_resources_tick.erl)
chains_([C = ?INFINITE_LOOP | Live], Dead, AllPairs) ->
    chains_(Live, [lists:reverse(C) | Dead], AllPairs);
chains_([CurrChain | LiveChains], DeadChains, AllPairs) ->
    [Head | Prev] = CurrChain,

    io:format(user, "Current chain = ~p~n", [CurrChain]),

    IsMatch = fun (Next) -> is_pair_match(Prev, Head, Next) end,
    LinkedPairs = lists:filter(IsMatch, AllPairs),

    case LinkedPairs of
        [] ->
            chains_(LiveChains, [lists:reverse(CurrChain) | DeadChains], AllPairs);
        _ ->
            NewChains = [[N | CurrChain] || N <- LinkedPairs],
            chains_(NewChains ++ LiveChains, DeadChains, AllPairs)
    end.

is_pair_match(PrevPairs, Curr, MaybeNext) ->
    EqualsNext = fun(PrevPair) -> is_pair_equal(PrevPair, MaybeNext) end,
    not lists:any(EqualsNext, PrevPairs)
    andalso
    is_pair_match(Curr, MaybeNext).

is_pair_equal({_, _, A1, R1}, {_, _, A2, R2}) ->
    are_events_equal(A1, A2) andalso are_events_equal(R1, R2).

are_events_equal({E, _, Types1}, {E, _, Types2}) ->
    is_type_match(Types1, Types2);
are_events_equal(_, _) ->
    false.

is_pair_match(Pair1, Pair2) ->
    {_, _, _, {ReactionEvent, _, RTypess}} = Pair1,
    {_, _, {ActionEvent, _, ATypess}, _} = Pair2,
    ReactionEvent == ActionEvent
    andalso
    is_type_match(RTypess, ATypess).

is_type_match(Types1, Types2) ->
    Pairs = lists:zip(Types1, Types2),
    lists:all(fun is_type_match/1, Pairs).

is_type_match({'_', _}) -> true;
is_type_match({_, '_'}) -> true;
is_type_match({Type,Type}) -> true;
is_type_match(_) -> false.

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
    %TypeBin = type_bin(Types),
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

%type_bin(Event, Types) when is_list(Event)->
%    type_bin(tuple_to_list(Event), Types, []).
%
%type_bin([Index | Event], [{Index, Type} | Types], IoList) ->
%    type_bin(Event, Types, [Type | IoList]);
%type_bin([Index | Event], Types, IoList) ->
%    type_bin(Event, Types, [<<"_">> | IoList]);
