-module(egre_protocol_event_chains).

-export([extract/1]).
-export([get_events/1]).
-export([write_events/1]).

-define(API_FUNCTION_ARITY, 1).

-record(state, {events = [],
                type_map = #{},
                variables = #{}}).

extract(ApiFuns) ->
  Events = get_events(ApiFuns),
  write_events(Events).

get_events(ApiClauses) ->
    lists:foldl(fun get_event_pairs/2, [], ApiClauses).

write_events(_) ->
    ok.

get_event_pairs({_K, {clause, [{var, '_'}], _, _}}, Events) ->
    Events;
get_event_pairs({{Module, attempt, ?API_FUNCTION_ARITY}, {clause, Arguments, Conjunction, Body}},
          Events) ->
    TypeMap = lists:foldl(fun type_inference/2, #{}, Conjunction),
    State = #state{type_map = TypeMap},

    [{tuple, [_CustomData, _Props, Event, _Context]}] = Arguments,

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

    NewEvents = [[Module, attempt, ActionEvent, ReactionEvent] || ReactionEvent <- ReactionEvents],
    Events ++ NewEvents;
get_event_pairs({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}, Events) ->
    Events.

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
type_inference(Other, TypeMap) ->
    ct:pal("~p:~p: Other~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Other]),
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

indexed_event({var, EventVar}, State = #state{variables = Variables}) ->
    #{EventVar := Event} = Variables,
    indexed_event(Event, State);
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
    {IndexedEventTuple, IndexedVariables, IndexedTypes}.

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
    {Index, Event ++ [Atom], IndexedVariables, Types, TypeMap}.
