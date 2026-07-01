-module(decouple_orelse_out).

-export([attempt/1]).

attempt({A, B, {x}, x}) when A == 1 ->
    ok;
attempt({A, B, {x}, x}) when B == 1 ->
    ok.
