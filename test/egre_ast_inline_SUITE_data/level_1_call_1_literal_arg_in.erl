-module(level_1_call_1_literal_arg_in).

-export([attempt/1]).

attempt(_) ->
    call_one_arg(ok).

call_one_arg(Var) ->
    {return, Var}.
