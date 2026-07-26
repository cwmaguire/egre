-module(egre_protocol_props_inference).

-export([maybe_props_var/2]).
-export([find_prop_types/2]).

-record(state, {events = [],
                type_map = #{},
                variables = #{},
                props = [],
                prop_types = #{}}).

maybe_props_var(attempt, [{match, _, {tuple, [_, {var, PropsVar}, _, _]}}]) ->
    maybe_props_var(PropsVar);
maybe_props_var(attempt, [{tuple, [_, {var, PropsVar}, _, _]}]) ->
    maybe_props_var(PropsVar);
maybe_props_var(succeed, [{tuple, [{var, PropsVar}, _, _]}]) ->
    maybe_props_var(PropsVar);
%% Not sure what this covers
maybe_props_var(succeed, _) ->
    undefined.

maybe_props_var(PropsVar) ->
    case atom_to_list(PropsVar) of
        [$_ | _] ->
            undefined;
        _ ->
            PropsVar
    end.

find_prop_types({match, {var, Var}, Forms}, State = #state{}) ->
    State1 = find_prop_types(Forms, State),
    IsPropsValue = does_return_properties(Forms, State#state.props),
    MaybePropType = maybe_property_type(Forms, State),
    case {IsPropsValue, MaybePropType} of
        {true, _} ->
            %% XXX should this be a cons onto the existing props?
            State1#state{props = [_NewPropsVar = Var | State1#state.props]};
        {_, undefined} ->
            State1;
        {_, Type} ->
            case State#state.type_map of
                #{Var := _} ->
                    State1;
                _ ->
                    State1#state{type_map = (State#state.type_map)#{Var => Type}}
            end
    end;
find_prop_types({'case', Expression, [Clause = {clause, _, _, _}]}, State) ->
    State1 = find_prop_types(Expression, State),
    find_prop_types(Clause, State1);
find_prop_types({clause,
                 _Expression,
                 _Guards,
                 Body},
                State) ->
    lists:foldl(fun find_prop_types/2, State, Body);
%% TODO Why aren't we using Expression2?
find_prop_types({op, 'orelse', Expression1, _Expression2}, State) ->
    State1 = find_prop_types(Expression1, State),
    find_prop_types(Expression1, State1);
%% TODO Why aren't we using Expression2?
find_prop_types({op, 'andalso', Expression1, _Expression2}, State) ->
    State1 = find_prop_types(Expression1, State),
    find_prop_types(Expression1, State1);
find_prop_types({call,
                 {remote, {atom, egre_object}, {atom, has_pid}},
                 [{var, Var1}, {var, Var2}]},
                State = #state{type_map = TypeMap, props = Props}) ->
    case TypeMap of
        _Var2AlreadyTyped = #{Var2 := _} ->
            State;
        _ ->
            case lists:member(Var1, Props) of
                true ->
                    State#state{type_map = TypeMap#{Var2 => pid}};
                _ ->
                    State
            end
    end;
find_prop_types(_Form, State) ->
    State.

%% TODO: Is this an expression that returns a Props value?
%% e.g. [{a, 1} || Props]
%% That is, are we assigning Props to a new variable; if so, we'll need to track that this is now a
%% variable holding properties. We need to monitor it for property types.
%% e.g. if we pull 'a' out, then we know 'a' is an integer property. If we use a in a reaction event,
%% then we know that event has an integer
does_return_properties({var, Var}, Props) ->
    lists:member(Var, Props);
does_return_properties(_Forms, _Props) ->
    false.

%% Are we pulling a typed property out of Props? If so, what type?
maybe_property_type({call,
                     {remote, {atom, proplists}, {atom, get_value}},
                     [{atom, Prop}, {var, MaybePropsVar}]},
                    #state{props = Props,
                           prop_types = PropTypes}) ->
    case {lists:member(MaybePropsVar, Props), PropTypes} of
        {true, #{Prop := Type}} ->
            Type;
        _ ->
            undefined
    end;
maybe_property_type(_, _) ->
    undefined.
