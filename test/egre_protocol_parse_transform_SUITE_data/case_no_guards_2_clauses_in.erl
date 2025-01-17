-module(case_no_guards_2_clauses_in).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 ->
            ok;
        2 ->
            foo
    end,
    B = 2.

