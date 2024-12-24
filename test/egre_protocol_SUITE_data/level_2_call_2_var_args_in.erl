-module(level_2_call_2_var_args_in).

-export([attempt/1]).

attempt(_) ->
    X = 1,
    Y = a,
    call_two_args(X, Y).

call_two_args(W, Z) when W == 1 ->
    call_no_args_1();
call_two_args(W, Z) when Z == a ->
    call_no_args_2().

call_no_args_1() ->
    ok.

call_no_args_2() ->
    foo.
