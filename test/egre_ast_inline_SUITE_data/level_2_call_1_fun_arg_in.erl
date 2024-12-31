-module(level_2_call_1_fun_arg_in).

-export([attempt/1]).

attempt(_) ->
    X = 1,
    call_one_arg(call_two_args(X, a)).

call_two_args(W, Z) when W == 1 ->
    ok;
call_two_args(W, Z) when Z == a ->
    foo.

call_one_arg(A) ->
    {A, 1}.
