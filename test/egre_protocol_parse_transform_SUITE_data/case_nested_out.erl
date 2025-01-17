-module(case_nested_out).

-export([attempt/1]).

attempt(_) ->
    A = 1,
    case A of
        1 when true ->
           case self() of
               P when is_pid(P) ->
                   bar
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when true ->
           case self() of
               P when true ->
                   bar
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when true ->
           case self() of
               Q when 2 == 3 ->
                   baz
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when true ->
           case self() of
               Q when 4 > 3 ->
                   baz
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when is_integer(A) ->
           case self() of
               P when is_pid(P) ->
                   bar
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when is_integer(A) ->
           case self() of
               P when true ->
                   bar
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when is_integer(A) ->
           case self() of
               Q when 2 == 3 ->
                   baz
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        1 when is_integer(A) ->
           case self() of
               Q when 4 > 3 ->
                   baz
           end
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        2 when 1 == 1 ->
            foo
    end,
    B = 2;
attempt(_) ->
    A = 1,
    case A of
        2 when is_binary(self()) ->
            foo
    end,
    B = 2.







