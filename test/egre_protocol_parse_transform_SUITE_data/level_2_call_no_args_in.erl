-module(level_2_call_no_args_in).

-export([attempt/1]).

attempt(_) ->
    call_1_no_args().

call_1_no_args() ->
    call_2_no_args().

call_2_no_args() ->
    {return, ok}.
