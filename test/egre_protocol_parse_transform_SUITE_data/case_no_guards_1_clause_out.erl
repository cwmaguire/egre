-module(case_no_guards_1_clause_out).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 ->
            ok
    end,
    B = 2.
