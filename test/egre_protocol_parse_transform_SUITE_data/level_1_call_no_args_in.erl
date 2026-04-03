-module(level_1_call_no_args_in).

-export([attempt/1]).

attempt(_) ->
    call_no_args().

call_no_args() ->
    ok.
