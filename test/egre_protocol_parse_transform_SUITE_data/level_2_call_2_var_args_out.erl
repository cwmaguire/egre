-module(level_2_call_2_var_args_out).

-export([attempt/1]).

attempt(_) ->
    X = 1,
    Y = a,
    case {X, Y} of
        {W, Z} when W == 1 ->
            case {} of
                {} ->
                    ok
            end
    end;
attempt(_) ->
    X = 1,
    Y = a,
    case {X, Y} of
        {W, Z} when Z == a ->
            case {} of
                {} ->
                    foo
            end
    end.
