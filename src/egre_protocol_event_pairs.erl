-module(egre_protocol_event_pairs).

-export([extract/1]).
-export([get_events/1]).
-export([write_events/1]).

-define(API_FUNCTION_ARITY, 1).

-record(state, {events = [],
                type_map = #{},
                variables = #{}}).

%% FIXME
%%  src/rules/rules_body_part_inject_self.erl: error in parse transform 'egre_protocol_parse_transform':
%%  exception error: no function clause matching egre_protocol_event_chains:index_variable({call,{atom,self},[]},{2,[1,move,from],[{1,<<"Item">>}],[],#{}}) (src/egre_protocol_event_chains.erl, line 197)


extract(ApiFuns) ->
    %egre_dbg:add(egre_protocol_event_pairs, get_event_pairs),
    %egre_dbg:add(egre_protocol_event_pairs, indexed_event),
    %egre_dbg:add(egre_protocol_event_pairs, index_variable),
    %egre_dbg:add(egre_protocol_event_pairs, reaction_events),
    Events = get_events(ApiFuns),
    egre_dbg:stop(),
    write_events(Events).

get_events(ApiClauses) ->
    lists:foldl(fun get_event_pairs/2, [], ApiClauses).

write_events([]) ->
    io:format("No events~n");
write_events(Events = [[Module | _] | _]) ->
    {ok, IO} = file:open(<<"events/", Module/binary, "_events.bert">>, [write]),
    file:write(IO, term_to_binary(Events)),
    file:close(IO).


get_event_pairs({_K, {clause, [{var, '_'}], _, _}}, Events) ->
    Events;
get_event_pairs({{Module, Function, ?API_FUNCTION_ARITY}, {clause, Arguments, Conjunction, Body}},
          Events)
  when Function == attempt;
       Function == succeed ->
    TypeMap = lists:foldl(fun type_inference/2, #{}, Conjunction),
    State = #state{type_map = TypeMap},

    Event = event(Function, Arguments),

    {ReactionEvents, TypeMap3} =
        case lists:foldl(fun reaction_events/2, State, Body) of
            #state{events = [],
                   type_map = TypeMap2} ->
                {[undefined], TypeMap2};
            #state{events = StateEvents,
                   type_map = TypeMap2} ->
                {StateEvents, TypeMap2}
        end,

    ActionEvent =
        {_IndexedEvent, _IndexedVariables, _IndexedTypes} =
            indexed_event(Event, State#state{type_map = TypeMap3}),

    case {Function, ActionEvent, ReactionEvents} of
        _NoActionEvent = {_, {[], _, _}, _} ->
            Events;
        _NoReactionEvent = {attempt, _, [undefined]} ->
            Events;
        _ ->
            NewEvents = [[Module, Function, ActionEvent, ReactionEvent] || ReactionEvent <- ReactionEvents],
            Events ++ NewEvents
    end;
get_event_pairs({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}, Events) ->
    Events.

event(attempt, [{match, _, {tuple, [_, _, {var, Event}, _]}}]) ->
    maybe_var_event(Event);
event(attempt, [{tuple, [_, _, Event, _]}]) ->
    Event;
event(succeed, [{tuple, [_, {var, Event}, _]}]) ->
    maybe_var_event(Event);
event(succeed, [{tuple, [_Props, Event, _Context]}]) ->
    Event.

maybe_var_event(Event) ->
    case atom_to_list(Event) of
        [$_ | _] ->
            {var, '_'};
        _ ->
            {var, Event}
    end.

type_inference({op, '==', Operand1, {var, Var}}, TypeMap) ->
    type_inference( {op, '==', {var, Var}, Operand1}, TypeMap);
type_inference({op, '==', {var, Var}, Operand1}, TypeMap) ->
    case type_inference_equals(Operand1) of
        undefined ->
            TypeMap;
        Type ->
            TypeMap#{Var => Type}
    end;
type_inference({call, {atom, is_pid}, [{var, Var}]}, TypeMap) ->
    TypeMap#{Var => pid};
type_inference({match, {var, Var1}, {var, Var2}}, TypeMap) ->
    case TypeMap of
        #{Var2 := Type} ->
            TypeMap#{Var1 => Type};
        _ ->
            TypeMap
    end;
type_inference(_Other, TypeMap) ->
    %ct:pal("~p:~p: Other~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Other]),
    TypeMap.

type_inference_equals({call, {atom, self}, []}) ->
    pid;
type_inference_equals({atom, _}) ->
    atom;
type_inference_equals({integer, _}) ->
    integer;
type_inference_equals({float, _}) ->
    float;
type_inference_equals({string, _}) ->
    string;
type_inference_equals({char, _}) ->
    char;
type_inference_equals({nil}) ->
    list;
type_inference_equals({cons, _}) ->
    list;
type_inference_equals({bin, _}) ->
    bin;
type_inference_equals(_) ->
    undefined.

%% TODO go look at actual rules modules to see what kind of type inference cases I need
%% to watch for.

reaction_events({call,
                 {remote,
                  {atom, egre},
                  {atom, attempt}},
                 [_Target,
                  Event | _MaybeSub]},
                State = #state{events = Events}) ->
    ReactionEvent = indexed_event(Event, State),
    State#state{events = [ReactionEvent | Events]};
reaction_events({call,
                 {remote,
                  {atom, egre},
                  {atom, attempt_after}},
                 [_TickTime,
                  _Target,
                  Event]},
                State = #state{events = Events}) ->
    ReactionEvent = indexed_event(Event, State),
    State#state{events = [ReactionEvent | Events]};
reaction_events({record, result, RecordFields},
                State) ->
    maybe_result_record_event(RecordFields, State);
reaction_events(Match = {match, {var, Var1}, {var, Var2}},
                State = #state{variables = Variables,
                               type_map = TypeMap}) ->
    Variables2 =
        case Variables of
            #{Var2 := Value} ->
                Variables#{Var1 => Value};
            _ ->
                Variables#{Var1 => Var2}
        end,

    TypeMap2 = type_inference(Match, TypeMap),
    State#state{variables = Variables2,
                type_map = TypeMap2};
% TODO consider other cases where a bare '+' might occur,
% such as a case expression:
% case A + B of X ... end
reaction_events({match, {var, Var3}, {op, Op, {var, Var1}, {var, Var2}}},
                State = #state{type_map = TypeMap})
  when Op == '+';
       Op == '-' ->
    State#state{type_map = TypeMap#{Var1 => integer,
                                    Var2 => integer,
                                    Var3 => integer}};
reaction_events({match, {var, Var}, Value = {tuple, _}},
                State = #state{variables = Variables}) ->
    % TODO recurse through the assignment, e.g. when assigning from a
    % case statement (e.g. an inlined function call, or remote call)
    %
    % e.g. [{1, <<"Character">>}, {2, <<"proplists:get_value(a, List)">>}]
    State#state{variables = Variables#{Var => Value}};
reaction_events({match, {var, Var},
                 Case = {'case', _, [{clause, _, _, ClauseExprs}]}},
                State = #state{variables = Variables}) ->
    State2 = reaction_events(Case, State),
    LastClauseExpr = hd(lists:reverse(ClauseExprs)),
    Variables2 = Variables#{Var => LastClauseExpr},
    State2#state{variables = Variables2};
reaction_events({match, {var, Var},
                 {call,
                  {remote, {atom, 'proplists'}, {atom, 'get_value'}},
                  [_, _, {integer, _}]}},
                State = #state{type_map = TypeMap}) ->
    State#state{type_map = TypeMap#{Var => integer}};
reaction_events({op, Op, {var, Var1}, {var, Var2}},
                State = #state{type_map = TypeMap})
  when Op == '+';
       Op == '-' ->
    State#state{type_map = TypeMap#{Var1 => integer,
                                    Var2 => integer}};
reaction_events(Form, State) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    reaction_events(List, State);
reaction_events(Forms, State) when is_list(Forms) ->
    lists:foldl(fun reaction_events/2,
                State,
                Forms);
reaction_events(_Form, State) ->
    %ct:pal("~p:~p: _Form~n\t~p~n\t~p~n", [?MODULE, ?FUNCTION_NAME, _Form, State]),
    State.

maybe_result_record_event(RecordFields, State) ->
    lists:foldl(fun maybe_result_record_field_event/2, State, RecordFields).

maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, resend}, _Target, Event]}},
                                State = #state{events = Events}) ->
    State#state{events = [indexed_event(Event, State) | Events]};
maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, broadcast}, Event]}},
                                State = #state{events = Events}) ->
    State#state{events = [indexed_event(Event, State) | Events]};
maybe_result_record_field_event({record_field,
                                 {atom, event},
                                 Event = {tuple, _}},
                                State = #state{events = Events}) ->
    State#state{events = [indexed_event(Event, State) | Events]};
maybe_result_record_field_event(_, State) ->
    State.

% {match,{var,'_Active'},{cons,{var,'_'},{var,'_'}}}

indexed_event({var, '_'}, _) ->
    {[], #{}, #{}};
indexed_event({match, {var, MaybeIgnored}, Event},
              State = #state{variables = Variables}) ->
    case atom_to_list(MaybeIgnored) of
        [$_ | _] ->
            indexed_event(Event, State);
        _ ->
            indexed_event(Event, State#state{variables = Variables#{MaybeIgnored => Event}})
    end;
indexed_event({var, EventVar}, State = #state{variables = Variables}) ->
    %io:format(user, "EventVar = ~p~n", [EventVar]),
    %io:format(user, "State = ~p~n", [State]),
    case Variables of
        #{EventVar := Event} ->
            indexed_event(Event, State);
        _ ->
            {[], #{}, #{}}
    end;
indexed_event({tuple, Event}, #state{type_map = TypeMap}) ->
    Acc = {1,
           _Event = [],
           _Variables = [],
           _Types = [],
           TypeMap},
    {_NextIdx,
     IndexedEvent,
     IndexedVariables,
     IndexedTypes,
     _TypeInf} =
        lists:foldl(fun index_variable/2, Acc, Event),
    IndexedEventTuple = list_to_tuple(IndexedEvent),
    {IndexedEventTuple, IndexedVariables, IndexedTypes};
indexed_event({call, {atom, Fun}, [{var, Var}]}, _State) ->
    VarBin = atom_to_binary(Var),
    {{Fun, '(', 1, ')'}, [{1, VarBin}], []}.

index_variable({integer, Int}, {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, integer_to_binary(Int)}],
     [{Index, integer} | Types],
     TypeMap};
index_variable({var, Var}, {Index, Event, IndexedVariables, Types, TypeMap}) ->
    Types2 =
        case TypeMap of
            #{Var := Type} ->
                [{Index, Type} | Types];
            _ ->
                Types
        end,
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
     [{Index, integer} | Types],
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
     [{Index, pid} | Types],
     TypeMap};

index_variable({match, {var, Var}, {record, RecordType, _Fields}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    BinVar = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<BinVar/binary>>}],
     [{Index, RecordType} | Types],
     TypeMap};
index_variable({match, {var, Var}, {atom, _}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    BinVar = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, BinVar}],
     [{Index, atom} | Types],
     TypeMap};
index_variable({match, {var, Var}, {nil}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    VarBin = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<VarBin/binary, " = []">>}],
     [{Index, list} | Types],
     TypeMap};
index_variable({match, {var, Var}, Cons = {cons, _, _}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    VarBin = atom_to_binary(Var),
    ConsBin = serialize_cons(Cons),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<VarBin/binary, " = ", ConsBin/binary>>}],
     [{Index, list} | Types],
     TypeMap};

%{match,{var,'_Phrase'},
       %{bin,[{bin_element,{string,"quest "},default,default},
             %{bin_element,{var,'QuestName'},default,[binary]}]}}

index_variable({match, {var, Var}, {bin, _}},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    VarBin = atom_to_binary(Var),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<VarBin/binary, " = <binary>">>}],
     [{Index, list} | Types],
     TypeMap};
index_variable({record, RecordName, _Fields},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    RecordNameBin = atom_to_binary(RecordName),
    RecordTypeBin = <<"#", RecordNameBin/binary, "{}">>,
    RecordTypeAtom = binary_to_atom(RecordTypeBin),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, RecordTypeBin}],
     [{Index, RecordTypeAtom} | Types],
     TypeMap};
index_variable({tuple, Exprs},
               {NextIdx0, Event, IndexedVariables0, IndexedTypes0, TypeInfo0}) ->
    Acc = {NextIdx0,
           [],
           IndexedVariables0,
           IndexedTypes0,
           TypeInfo0},
    {NextIdx,
     IndexedTuple,
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
     [{Index, list} | Types],
     TypeMap};
index_variable(Cons = {cons, _, _},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    ConsBin = serialize_cons(Cons),
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, ConsBin}],
     [{Index, list} | Types],
     TypeMap};
index_variable({'case', _Expr, _Clauses},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"case">>}],
     [{Index, 'case'} | Types],
     TypeMap};
index_variable({bin, _},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"<binary>">>}],
     [{Index, bin} | Types],
     TypeMap};
index_variable({nil},
               {Index, Event, IndexedVariables, Types, TypeMap}) ->
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, <<"[]">>}],
     [{Index, list} | Types],
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

