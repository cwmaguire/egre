-module(level_1_call_no_args_out).

-export([attempt/1]).

attempt(_) ->
    case {} of
        {} ->
           ok
    end.
