-module(level_2_call_recursive_in).

-export([succeed/1]).

succeed(_) ->
    call_1_no_args().

call_1_no_args() ->
    call_2_no_args().

call_2_no_args() ->
    call_2_no_args().

