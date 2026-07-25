-module(case_expression_orelse_out).

-export([attempt/1]).

attempt({A, B, {x}, _C}) ->
    case false of
        false ->
            B
    end;
attempt({A, B, {x}, _C}) ->
    case false of
        true ->
            A
    end;
attempt({A, B, {x}, _C}) ->
    case true of
        false ->
            B
    end;
attempt({A, B, {x}, _C}) ->
    case true of
        true ->
            A
    end.
