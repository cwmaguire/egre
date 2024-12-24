-module(level_1_call_1_var_arg_in).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    call_one_arg(A).

call_one_arg(Var) ->
    {return, Var}.
