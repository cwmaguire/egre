-module(level_1_call_1_var_arg_out).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case {A} of
        {Var} ->
            {return, Var}
    end.
