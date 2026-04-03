-module(level_2_call_recursive_out).

-export([succeed/1]).

succeed(_) ->
    case {} of
        {} ->
            case {} of
                {} ->
                    call_2_no_args()
            end
    end.

call_2_no_args() ->
    ok.
