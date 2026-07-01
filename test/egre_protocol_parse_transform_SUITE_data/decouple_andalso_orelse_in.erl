-module(decouple_andalso_orelse_in).

-export([attempt/1]).

attempt({A, B, {x}, x}) when A == 1 andalso (B == 1 orelse B == 2) ->
    ok.
