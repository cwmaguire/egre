-module(case_no_guards_2_clauses_out).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 ->
            ok
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        2 ->
            foo
    end,
    B = 2.
