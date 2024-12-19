-module(level_1_call_no_args_out).

-export([attempt/1]).

attempt(_) ->
    Call_no_args =
        begin
            ok
        end.
