-module(egre_protocol_event_index).

-export([index_event/2]).


-record(state, {events = [],
                type_map = #{},
                variables = #{},
                props = [],
                prop_types = #{}}).


index_event({var, '_'}, _) ->
    {[], [], []};
index_event({match, {var, MaybeIgnored}, Event},
              State = #state{variables = Variables}) ->
    case atom_to_list(MaybeIgnored) of
        [$_ | _] ->
            index_event(Event, State);
        _ ->
            index_event(Event, State#state{variables = Variables#{MaybeIgnored => Event}})
    end;
index_event({var, EventVar}, State = #state{variables = Variables}) ->
    %io:format(user, "EventVar = ~p~n", [EventVar]),
    %io:format(user, "State = ~p~n", [State]),
    case Variables of
        #{EventVar := Event} ->
            index_event(Event, State);
        _ ->
            {[], [], []}
    end;
index_event({tuple, Event}, #state{type_map = TypeMap}) ->
    Acc = {1,
           _Event = [],
           _Variables = [],
           _Types = [],
           TypeMap},
    {_NextIdx,
     [_ | _] = IndexedEvent,
     IndexedVariables,
     IndexedTypes,
     _TypeInf} =
        lists:foldl(fun index_variable/2, Acc, Event),
    IndexedEventTuple = list_to_tuple(IndexedEvent),
    {IndexedEventTuple, IndexedVariables, IndexedTypes};
index_event({call, {atom, Fun}, [{var, Var}]}, _State) ->
    VarBin = atom_to_binary(Var),
    {{Fun, '(', 1, ')'}, [{1, VarBin}], []}.



index_variable({integer, Int}, {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, integer_to_binary(Int)}],
     % [{Index, integer} | Types],
     Types ++ [{Index, integer}],
     TypeMap};
index_variable({var, Var}, {Index, Event, IndexedVariables, Types, TypeMap}) ->
    io:format(user, "Checking if var ~p has type in Types: ~p~n", [Var,  Types]),
    Types2 =
        case TypeMap of
            #{Var := Type} ->
                %[{Index, Type} | Types];
                Types ++ [{Index, Type}];
            _ ->
                Types
        end,
    io:format(user, "Maybe new types: ~p~n", [Types2]),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, atom_to_binary(Var)}],
     Types2,
     TypeMap};
index_variable({op, Op, {var, Var1}, {var, Var2}}, {Index, Event, IndexedVariables, Types, TypeMap})
  when Op == '+';
       Op == '-' ->
    BinOp = atom_to_binary(Op),
    BinVar1 = atom_to_binary(Var1),
    BinVar2 = atom_to_binary(Var2),
    BinExpression = <<"(", BinVar1/binary, " ", BinOp/binary, " ", BinVar2/binary, ")">>,
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, BinExpression}],
     % [{Index, integer} | Types],
     Types ++ [{Index, integer}],
     TypeMap#{Var1 => integer, Var2 => integer}};
index_variable({atom, Atom}, {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index,
     Event ++ [Atom],
     IndexedVariables,
     Types,
     TypeMap};
index_variable({call, {atom, self}, []}, {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"self()">>}],
     Types ++ [{Index, pid}],
     TypeMap};
index_variable({match, {var, Var}, {record, RecordType, _Fields}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    BinVar = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<BinVar/binary>>}],
     % [{Index, RecordType} | Types],
     Types ++ [{Index, RecordType}],
     TypeMap};
index_variable({match, {var, Var}, {atom, _}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    BinVar = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, BinVar}],
     % [{Index, atom} | Types],
     Types ++ [{Index, atom}],
     TypeMap};
index_variable({match, {var, Var}, {nil}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    VarBin = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<VarBin/binary, " = []">>}],
     % [{Index, list} | Types],
     Types ++ [{Index, list}],
     TypeMap};
index_variable({match, {var, Var}, Cons = {cons, _, _}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    VarBin = atom_to_binary(Var),
    ConsBin = serialize_cons(Cons),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<VarBin/binary, " = ", ConsBin/binary>>}],
     % [{Index, list} | Types],
     Types ++ [{Index, list}],
     TypeMap};
index_variable({match, {var, Var}, {bin, _}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    VarBin = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<VarBin/binary, " = <binary>">>}],
     % [{Index, list} | Types],
     Types ++ [{Index, list}],
     TypeMap};
index_variable({record, RecordName, _Fields},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    RecordNameBin = atom_to_binary(RecordName),
    RecordTypeBin = <<"#", RecordNameBin/binary, "{}">>,
    RecordTypeAtom = binary_to_atom(RecordTypeBin),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, RecordTypeBin}],
     % [{Index, RecordTypeAtom} | Types],
     Types ++ [{Index, RecordTypeAtom}],
     TypeMap};
index_variable({tuple, Exprs},
               {NextIdx0, Event, IndexedVariables0, IndexedTypes0, TypeInfo0}) ->
    Acc = {NextIdx0,
           [],
           IndexedVariables0,
           IndexedTypes0,
           TypeInfo0},
    {NextIdx,
     [_ | _] = IndexedTuple,
     IndexedVariables,
     IndexedTypes,
     TypeInf} =
        lists:foldl(fun index_variable/2, Acc, Exprs),
    {NextIdx,
     Event ++ [list_to_tuple(IndexedTuple)],
     IndexedVariables,
     IndexedTypes,
     TypeInf};
%% TODO use {cons, _, _} logic, since this is a subset of that
index_variable({cons, {var, Var1}, {var, Var2}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    BinVar1 = atom_to_binary(Var1),
    BinVar2 = atom_to_binary(Var2),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"[", BinVar1/binary, " | ", BinVar2/binary, "]">>}],
     % [{Index, list} | Types],
     Types ++ [{Index, list}],
     TypeMap};
index_variable(Cons = {cons, _, _},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    ConsBin = serialize_cons(Cons),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, ConsBin}],
     % [{Index, list} | Types],
     Types ++ [{Index, list}],
     TypeMap};
index_variable({'case', _Expr, _Clauses},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"case">>}],
     Types,
     TypeMap};
index_variable({op, _Op, _Operand},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"operation">>}],
     Types,
     TypeMap};
index_variable({bin, _},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"<binary>">>}],
     % [{Index, bin} | Types],
     Types ++ [{Index, bin}],
     TypeMap};
index_variable({nil},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"[]">>}],
     % [{Index, list} | Types],
     Types ++ [{Index, list}],
     TypeMap}.

serialize_cons(Cons) ->
    serialize_cons(Cons, <<>>).

serialize_cons({cons, X, {nil}}, Bin) ->
    XBin = serialize(X),
    <<"[", Bin/binary, ", ", XBin/binary, "]">>;
serialize_cons({cons, X, Y = {var, _}}, Bin) ->
    XBin = serialize(X),
    YBin = serialize(Y),
    <<"[", Bin/binary, ", ", XBin/binary, " | ", YBin/binary, "]">>;
serialize_cons({cons, X, Rest}, Bin) ->
    XBin = serialize(X),
    Bin2 = <<Bin/binary, ", ", XBin/binary>>,
    serialize_cons(Rest, Bin2).

serialize({bin, [{bin_element, {var, Var}, default, [binary]}]}) ->
    atom_to_binary(Var);
serialize({var, Var}) ->
    atom_to_binary(Var).

