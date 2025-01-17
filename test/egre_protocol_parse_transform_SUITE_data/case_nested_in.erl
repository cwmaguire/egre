-module(case_nested_in).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 when true; is_integer(A) ->
            case self() of
                P when is_pid(P) ; true ->
                    bar;
                Q when 2 == 3 ; 4 > 3 ->
                    baz
            end;
        2 when 1 == 1; is_binary(self()) ->
            foo
    end,
    B = 2.





