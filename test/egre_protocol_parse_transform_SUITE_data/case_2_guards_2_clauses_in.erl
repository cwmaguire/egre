-module(case_2_guards_2_clauses_in).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 when true; is_integer(A) ->
            ok;
        2 ->
            foo
    end,
    B = 2.



