-module(egre_protocol_guards_inference).

-export([infer/2]).

infer(List, Acc) when is_list(List) ->
    lists:foldl(fun infer/2, Acc, List);

infer({op, Op, Expression1, Expression2}, Acc)
  when Op == 'andalso'; Op == 'orelse' ->
    Acc1 = infer(Expression1, Acc),
    _Acc2 = infer(Expression2, Acc1);
infer({op, '==', {var, Var1}, {var, Var2}}, Acc = TypeMap) ->
    case TypeMap of
        #{Var1 := _Type1, Var2 := _Type2} ->
            Acc;
        #{Var1 := Type} ->
            TypeMap#{Var2 => Type};
        #{Var2 := Type} ->
            TypeMap#{Var1 => Type};
        _ ->
            Acc
    end;
infer({op, '==', Operand1, {var, Var}}, Acc) ->
    infer( {op, '==', {var, Var}, Operand1}, Acc);
infer({op, '==', {var, Var}, Operand1}, Acc = TypeMap) ->
    case infer_equals(Operand1) of
        undefined ->
            Acc;
        Type ->
            TypeMap#{Var => Type}
    end;
infer({call, {atom, is_pid}, [{var, Var}]}, TypeMap) ->
    TypeMap#{Var => pid};
infer({call, {atom, is_binary}, [{var, Var}]}, TypeMap) ->
    TypeMap#{Var => binary};
infer({match, {var, Var1}, {var, Var2}}, Acc = TypeMap) ->
    case TypeMap of
        #{Var2 := Type} ->
            TypeMap#{Var1 => Type};
        _ ->
            Acc
    end;
infer(_Other, Acc) ->
    Acc.

infer_equals({call, {atom, self}, []}) ->
    pid;
infer_equals({atom, _}) ->
    atom;
infer_equals({integer, _}) ->
    integer;
infer_equals({float, _}) ->
    float;
infer_equals({string, _}) ->
    string;
infer_equals({char, _}) ->
    char;
infer_equals({nil}) ->
    list;
infer_equals({cons, _}) ->
    list;
infer_equals({bin, _}) ->
    binary;
infer_equals(_) ->
    undefined.
