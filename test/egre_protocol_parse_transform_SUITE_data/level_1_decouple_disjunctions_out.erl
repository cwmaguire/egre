-module(level_1_decouple_disjunctions_out).

-export([attempt/1]).

attempt({A, B, {x}, x}) when A == 1 ->
%attempt({A, B}) ->
    ok;
attempt({A, B, {x}, x}) when B == 2 ->
    ok.
