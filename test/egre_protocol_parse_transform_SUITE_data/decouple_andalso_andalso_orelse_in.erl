-module(decouple_andalso_andalso_orelse_in).

-export([attempt/1]).

attempt({A, B, {x}, C}) when A == 1 andalso C == 3 andalso (B == 1 orelse B == 2) ->
    ok.
