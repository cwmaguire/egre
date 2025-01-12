-module(level_1_decouple_disjunctions_in).

-export([attempt/1]).

attempt({A, B, {x}, x}) when A == 1, B == 1; A == 2, B == 2 ->
    ok.
