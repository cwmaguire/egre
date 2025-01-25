-module(case_expression_is_nested_case_out).

-export([succeed/1]).

succeed(_) ->
    A = 1,
    B = 2,
    C = 3,
    _ = case
            case {A, B} of
                {A_, B_} when is_pid(A_) ->
                    A_ == proplists:get_value(owner, B_),
                    fun1_clause_1
            end
                of
            true ->
                case {C, B} of
                    {C_, B_} ->
                        fun2_clause_1
                end
        end;
succeed(_) ->
    A = 1,
    B = 2,
    C = 3,
    _ = case
            case {A, B} of
                {A_, B_} when is_pid(A_) ->
                    A_ == proplists:get_value(owner, B_),
                    fun1_clause_1
            end
                of
            true ->
                case_clause_2
        end;
succeed(_) ->
    A = 1,
    B = 2,
    C = 3,
    _ = case
            case {A, B} of
                {_, _} ->
                    fun1_clause_2
            end
                of
            true ->
                case_clause_2
        end.
%succeed(_) ->
    %A = 1,
    %B = 2,
    %C = 3,
    %_ = case
            %case {A, B} of
                %{_, _} ->
                    %fun1_clause_2
            %end
                %of
            %true ->
                %case {C, B} of
                    %{C_, B_} ->
                        %fun2_clause_1
                %end
        %end.
