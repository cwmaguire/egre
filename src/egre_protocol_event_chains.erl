-module(egre_protocol_event_chains).

-export([extract/1]).
-export([get_events/1]).
-export([write_events/1]).

-define(API_FUNCTION_ARITY, 1).

-record(state, {events = [],
                type_inference = #{},
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
    State = #state{type_inference = TypeMap},

    [{tuple, [_CustomData, _Props, Event, _Context]}] = Arguments,
    {IndexedEvent, IndexedVariables, IndexedTypes} =
        indexed_event(Event, State),
    ActionEvent = {IndexedEvent, IndexedVariables, IndexedTypes},

    ReactionEvents =
        case lists:foldl(fun reaction_events/2, State, Body) of
            #state{events = []} ->
                [{undefined, undefined, undefined}];
            #state{events = StateEvents} ->
                StateEvents
        end,

    NewEvents = [[Module, attempt, ActionEvent, ReactionEvent] || ReactionEvent <- ReactionEvents],
    Events ++ NewEvents;
get_event_pairs({{_Module, _Function, _}, {clause, _Bindings, _Guards, _Body}}, Events) ->
    Events.

type_inference(A = {op, '==', Operand1, {var, Var}}, TypeMap) ->
    ct:pal("~p:~p: A~n\t~p~n", [?MODULE, ?FUNCTION_NAME, A]),
    type_inference( {op, '==', {var, Var}, Operand1}, TypeMap);
type_inference(B ={op, '==', {var, Var}, {call, {atom, self}, []}}, TypeMap) ->
    ct:pal("~p:~p: B~n\t~p~n", [?MODULE, ?FUNCTION_NAME, B]),
    TypeMap#{Var => pid};
type_inference(Other, TypeMap) ->
    ct:pal("~p:~p: Other~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Other]),
    TypeMap.

reaction_events({call,
                 {remote,
                  {atom, egre},
                  {atom, attempt}},
                 [_Target,
                  Event | _MaybeSub]},
                State = #state{events = Events}) ->
    {IndexedEvent, IndexedVariables, IndexedTypes} =
        indexed_event(Event, State),
    ActionEvent = {IndexedEvent, IndexedVariables, IndexedTypes},
    State#state{events = [ActionEvent | Events]};
reaction_events({record, result, RecordFields},
                EventsVars) ->
    ct:pal("~p:~p: RecordFields~n\t~p~n", [?MODULE, ?FUNCTION_NAME, RecordFields]),
    maybe_result_record_event(RecordFields, EventsVars);
reaction_events({match, {var, Var}, Value},
                State = #state{variables = Variables}) ->
    % TODO recurse through the assignment, e.g. when assigning from a
    % case statement (e.g. an inlined function call, or remote call)
    %
    % e.g. [{1, <<"Character">>}, {2, <<"proplists:get_value(a, List)">>}]
    State#state{variables = Variables#{Var => Value}};
reaction_events(Form, State) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    reaction_events(List, State);
reaction_events(Forms, State) when is_list(Forms) ->
    lists:foldl(fun reaction_events/2,
                State,
                Forms);
reaction_events(_Form, State) ->
    ct:pal("~p:~p: _Form~n\t~p~n\t~p~n", [?MODULE, ?FUNCTION_NAME, _Form, State]),
    State.

maybe_result_record_event(RecordFields, State) ->
    lists:foldl(fun maybe_result_record_field_event/2, State, RecordFields).

maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, resend}, _Target, Event]}},
                                State = #state{events = Events}) ->
    State#state{events = [action_event(Event, State) | Events]};
maybe_result_record_field_event({record_field,
                                 {atom, result},
                                 {tuple, [{atom, broadcast}, Event]}},
                                State = #state{events = Events}) ->
    State#state{events = [action_event(Event, State) | Events]};
maybe_result_record_field_event({record_field,
                                 {atom, event},
                                 Event = {tuple, _}},
                                State = #state{events = Events}) ->
    State#state{events = [action_event(Event, State) | Events]};
maybe_result_record_field_event(_, State) ->
    State.

action_event(Event, State) ->
    {IndexedEvent, IndexedVariables, IndexedTypes} =
        indexed_event(Event, State),
    {IndexedEvent, IndexedVariables, IndexedTypes}.

indexed_event({var, EventVar}, State = #state{variables = Variables}) ->
    #{EventVar := Event} = Variables,
    indexed_event(Event, State);
indexed_event({tuple, Event}, #state{type_inference = TypeInference}) ->
    Acc = {1,
           _Event = [],
           _Variables = [],
           _Types = [],
           TypeInference},
    {_NextIdx,
     IndexedEvent,
     IndexedVariables,
     IndexedTypes,
     _TypeInf} =
        lists:foldl(fun index_variable/2, Acc, Event),
    IndexedEventTuple = list_to_tuple(IndexedEvent),
    {IndexedEventTuple, IndexedVariables, IndexedTypes}.

index_variable({var, Var}, {Index, Event, IndexedVariables, Types, TypeInference}) ->
    Types2 =
        case TypeInference of
            #{Var := Type} ->
                [{Index, Type} | Types];
            _ ->
                Types
        end,
    {Index + 1,
     Event ++ [Index],
     IndexedVariables ++ [{Index, atom_to_binary(Var)}],
     Types2,
     TypeInference};
index_variable({atom, Atom}, {Index, Event, IndexedVariables, Types, TypeInference}) ->
    {Index, Event ++ [Atom], IndexedVariables, Types, TypeInference}.
