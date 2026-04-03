-module(case_1_guard_2_clauses_in).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 when true ->
            ok;
        2 ->
            foo
    end,
    B = 2.


