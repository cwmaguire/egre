-module(decouple_orelse_in).

-export([attempt/1]).

attempt({A, B, {x}, x}) when A == 1 orelse B == 1 ->
    ok.
