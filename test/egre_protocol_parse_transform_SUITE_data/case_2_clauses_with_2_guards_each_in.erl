-module(case_2_clauses_with_2_guards_each_in).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 when true; is_integer(A) ->
            ok;
        2 when 1 == 1; is_binary(self()) ->
            foo
    end,
    B = 2.




