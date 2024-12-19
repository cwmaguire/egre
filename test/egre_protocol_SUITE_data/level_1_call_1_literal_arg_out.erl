-module(level_1_call_1_literal_arg_out).

-export([attempt/1]).

attempt(_) ->
    Call_one_arg =
        case ok of
            ok ->
                {return, ok}
        end.
