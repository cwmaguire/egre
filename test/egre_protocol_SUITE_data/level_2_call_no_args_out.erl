-module(level_2_call_no_args_out).

-export([attempt/1]).

attempt(_) ->
    Call_1_no_args =
        begin
            Call_2_no_args =
                begin
                    {return, ok}
                end
        end.
