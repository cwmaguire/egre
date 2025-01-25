-module(case_expression_is_nested_case_in).

-export([succeed/1]).

succeed(_) ->
    A = 1,
    B = 2,
    C = 3,
    _ = case fun1(A, B) of
            true ->
                fun2(C, B);
            _ ->
                case_clause_2
        end.

fun1(A_, B_) when is_pid(A_) ->
    A_ == proplists:get_value(owner, B_),
    fun1_clause_1;
fun1(_, _) ->
    fun1_clause_2.

fun2(C_, B_) ->
    fun2_clause_1.
