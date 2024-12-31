-module(level_2_call_no_args_out).

-export([attempt/1]).

attempt(_) ->
    case {} of
        {} ->
            case {} of
                {} ->
                    {return, ok}
            end
    end.
