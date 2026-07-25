-module(case_expression_orelse_in).

-export([attempt/1]).

attempt({A, B, {x}, _C}) ->
    case true orelse false of
        true ->
            A;
        false ->
            B
    end.
