-module(egre_protocol_event_chains).

-export([chains/0]).

chains() ->
    Data = filelib:fold_files("events", ~S".*\.bert", false, fun read_file/2, []),
    io:format(user, "Data = ~p~n", [Data]).

read_file(Filename, Data) ->
    {ok, Binary} = file:read_file(Filename, [read]),
    Term = binary_to_term(Binary),
    io:format(user, "Term = ~p~n", [Term]),
    Data ++ Term.
