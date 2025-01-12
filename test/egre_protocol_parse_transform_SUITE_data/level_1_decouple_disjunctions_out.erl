-module(level_1_decouple_disjunctions_out).

-export([attempt/1]).

attempt({A, B, {x}, x}) when A == 1, B == 1 ->
    ok;
attempt({A, B, {x}, x}) when A == 2, B == 2 ->
    ok.
