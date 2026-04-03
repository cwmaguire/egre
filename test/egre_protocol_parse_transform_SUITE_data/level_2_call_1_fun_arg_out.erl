-module(level_2_call_1_fun_arg_out).

-export([attempt/1]).

attempt(_) ->
    X = 1,
    case {
        case {X, a} of
            {W, Z} when W == 1 ->
                ok
        end
         } of
        {A} ->
            {A, 1}
    end;

attempt(_) ->
    X = 1,
    case {
        case {X, a} of
            {W, Z} when Z == a ->
                foo
        end
         } of
        {A} ->
            {A, 1}
    end.
