-module(level_1_call_1_literal_arg_out).

-export([attempt/1]).

attempt(_) ->
    case {ok} of
        {Var} ->
            {return, Var}
    end.
