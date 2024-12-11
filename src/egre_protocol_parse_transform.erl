%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_parse_transform).

-export([parse_transform/2]).

parse_transform(Forms, _Options) ->
    %io:format(user, "Forms = ~p~n", [Forms]),
    io:format("~~", []),

    Module = module(Forms),
    Events = events(Forms, #{module => Module,
                             sub => <<"false">>,
                             custom => <<>>,
                             new_event_tuples => [],
                             children => []}),

    Events2 = [serialize_events(E) || E <- Events, is_map(E)],

    AllEvents =
        maps:from_list(
          lists:zip(lists:seq(1, length(Events2)),
                    Events2)),

    AllEventsWithChildren =
        maps:map(fun(_K, Event) ->
                      find_children(Event, AllEvents)
                  end,
                  AllEvents),

    AllEventsWithParents =
        maps:map(fun(EventIndex, Event) ->
                      find_parents(EventIndex, Event, AllEventsWithChildren)
                  end,
                  AllEventsWithChildren),

    AllEventsSerialized =
        maps:map(fun(_, Event) ->
                         serialize(Event)
                 end,
                 AllEventsWithParents),

    TopLevelEvents =
        lists:filter(fun({_Idx, #{parents := []}}) ->
                         true;
                        (_) ->
                         false
                     end,
                     maps:to_list(AllEventsSerialized)),


    Filename = <<"protocol">>,
    {ok, IO} = file:open(Filename, [write, append]),
    %[write_event(File, Event) || Event <- EventsWithChildren],
    [write_event(IO, E, "", AllEventsSerialized) || {_K, E} <- TopLevelEvents],
    file:close(IO),

    Forms.

write_event(IO,
            #{header := Header,
              new_event_tuples := Spawn,
              children := Children},
            Indent,
            Events) ->
    case file:write(IO, [Indent, Header]) of
        ok ->
            ok;
        Error ->
            io:format(user, "Write failed: ~p~n~p~n", [Error, Header])
    end,

    [write_spawn(IO, Indent ++ "    ", S, Children, Events) || S <- Spawn].

write_spawn(IO, Indent, Event, SpawnChildren, Events) ->
    Children = proplists:get_value(Event, SpawnChildren, []),
    [write_child(IO, Indent ++ "    ", ChildIndex, Events) || ChildIndex <- Children].

write_child(IO, Indent, Index, Events) ->
    Child = maps:get(Index, Events),
    write_event(IO, Child, Indent, Events).

serialize_events(Event = #{event := EventIolist, new_event_tuples := NewTuplesIolist}) ->
    Event#{event => iolist_to_binary(EventIolist),
           new_event_tuples => [iolist_to_binary(Spawn) || Spawn <- NewTuplesIolist]}.

find_children(Event = #{new_event_tuples := Spawn}, AllEvents) when is_list(Spawn) ->
    {Event2, _} =
        lists:foldl(fun find_children_/2, {Event, AllEvents}, Spawn),
    Event2;
find_children(Other, _) ->
  io:format(user, "Other = ~p~n", [Other]),
    Other.

find_children_(Spawn, {Parent = #{children := Children}, AllEvents}) ->
    SpawnChildren =
        maps:filtermap(fun(K, #{event := Event}) when Spawn == Event ->
                               {true, K};
                          (_, _) ->
                               false
                       end,
                       AllEvents),
    {Parent#{children => [{Spawn, maps:values(SpawnChildren)} | Children]}, AllEvents}.

find_parents(ChildIndex, ChildEvent, Events) ->
    Parents =
        lists:filtermap(fun({ParentIndex, MaybeParent}) ->
                            case has_child(MaybeParent, ChildIndex) of
                                true ->
                                    {true, ParentIndex};
                                _ ->
                                    false
                            end
                        end,
                        maps:to_list(Events)),

    UniqueParents = lists:uniq(Parents),
    ChildEvent#{parents => UniqueParents}.

has_child(#{children := Spawn}, K) ->
    lists:any(fun({_, Children}) ->
                  lists:member(K, Children)
              end,
              Spawn).

serialize(EventMap = #{module := Module,
                       %context := Context,
                       matches := Matches,
                       guard_groups := GuardGroups,
                       stage := Stage,
                       sub := Sub,
                       event := Event,
                       custom := Custom}) ->
io:format(user, "EventMap = ~p~n", [EventMap]),
    %ContextBin = string:pad(io_lib:format("~p", [Context]), 16),
    EventField =
        case {GuardGroups, Custom} of
            {<<>>, <<>>} ->
                Event;
            _ ->
                [Event, <<" when ">>,
                 GuardGroups, <<" ">>,
                 Custom]
        end,

    EventBin = iolist_to_binary(EventField),

    Header =
        iolist_to_binary([string:pad(EventBin, 110, trailing),
                          string:pad(Module, 25),
                          string:pad(Stage, 9),
                          string:pad(Sub, 7),
                          %ContextBin,
                          <<" ">>,
                          Matches]),

    EventMap#{header => Header};

serialize(<<>>) ->
    <<>>;
serialize(Other) ->
    io:format("Couldn't serialize state:~n~p~n", [Other]),
    <<>>.

serialize_matches(MatchVarToIndexMap) ->
    SortedByIndex =
        lists:sort(fun({_MatchVar1, Index1}, {_MatchVar2, Index2}) ->
                       Index1 =< Index2
                   end,
                   maps:to_list(MatchVarToIndexMap)),
    [[integer_to_binary(V), <<": ">>, K, <<", ">>] || {K, V} <- SortedByIndex].

module([{attribute, _Line, module, Module} | _]) ->
    remove_prefix(<<"rules_">>, a2b(Module));
module([_ | Forms]) ->
    module(Forms);
module(_) ->
    <<"unknown">>.

remove_prefix(Prefix, Bin) ->
    case Bin of
        <<Prefix:(size(Prefix))/binary, Rest/binary>> ->
            Rest;
        Bin_ when Bin_ == Bin ->
            Bin
    end.

events(Forms, State) when is_list(Forms) ->
    %io:format(user, "Forms = ~p~n", [Forms]),
    List = [events(Form, State) || Form <- Forms],
    %io:format(user, "List = ~p~n", [List]),
    lists:flatten(List);
events({function,_Line, Name, _Arity, Clauses}, State) when Name == 'attempt' ->
    lists:map(fun(Clause) -> attempt_clause(Clause, State) end, Clauses);
events({function,_Line, Name, _Arity, Clauses}, State) when Name == 'succeed' ->
    lists:map(fun(Clause) -> succeed_clause(Clause, State) end, Clauses);
events(_Form, _State) ->
    <<>>.


%% We don't need to see catch-all clauses in the protocol
%% attempt(_) -> ...
attempt_clause({clause, _Line1, [{var, _Line2, '_'}], _, _}, _State) ->
    <<>>;

%% We don't need to see catch-all clauses in the protocol.
%% Sometimes we'll catch anything that falls through in order to output
%% missed events. We can ignore these.
attempt_clause({clause, _Line1, [{var, _Line2, _Var}], _, _}, _State) ->
    <<>>;

%% We don't need to see catch-all clauses in the protocol
%% attempt({_, _, _Msg, _}) -> ...
attempt_clause({clause,
                _Line1,
                [{tuple, _Lt,
                  [_IgnoreCustom,
                   {var, _Lv2, '_'},
                   {var, _Lv3, IgnoreEvent},
                   {var, _Lv4, '_'}]}],
                _GuardGroups,
                _Body}, _State)
  when IgnoreEvent == '_Msg';
       IgnoreEvent == '_' ->
    <<>>;

%% We don't need to see catch-all clauses in the protocol
%% attempt(_Foo = {_, _, _Msg, _}) -> ...
attempt_clause({clause,
                _Line1,
                [{match, _Line2, {var, _, _},
                  {tuple, _Line3, [{var, _Line4, '_'},
                                   {var, _Line5, '_'},
                                   {var, _Line6, '_Msg'},
                                   {var, _Line7, '_'}]}}],
                _GuardGroups,
                _Body}, _State) ->
    <<>>;

%% Strip off any Variable that the event is bound too: it screws up the sorting of events and we're just
%% interested in the events themselves, not what they're bound to.
%% attempt(Parents, Props, Message = {Bar, baz, Quux}) -> ...
attempt_clause({clause,
                Line1,
                [{tuple, Line2, [CustomData, Props, {match, _Line3, {var, _, _}, Event}]}],
                GuardGroups,
                Body},
               State) ->
    attempt_clause({clause, Line1, [{tuple, Line2, [CustomData, Props, Event]}], GuardGroups, Body}, State);

attempt_clause({clause, _Line, Head, GuardGroups, Body}, State) ->
    [{tuple, _Line2, [CustomData, Props, Event, Context]}] = Head,

    State1 = attempt_head(CustomData, Props, Event, Context, State),
    State2 = guard_groups(GuardGroups, State1),
    Matches = maps:get(matches, State2),
    State3 = State2#{matches => serialize_matches(Matches)},
    State4 = lists:foldl(fun search/2, State3, Body),
    State4.

attempt_head(CustomData, _Props, Event, Context, State) ->
    %{Parents, Props, Event}.
    {EventString, Matches} = event_tuple_string(Event),
    CustomDataBin = map(CustomData, Matches),
    ContextBin = print(Context),
    State#{custom => CustomDataBin,
           event => EventString,
           context => ContextBin,
           matches => Matches,
           stage => <<"attempt">>}.

%% I don't think you can get a function clause without a name
%succeed_clause({clause, _Line, Head, GuardGroups, Body}) ->
    %succeed_clause('', {clause, _Line, Head, GuardGroups, Body}).

succeed_clause({clause, _Line1, [{var, _Line2, '_'}], _, _}, _State) ->
    undefined;

%% We don't need to see catch-all clauses in the protocol
%% succeed({AnyVAr, _}) -> ...
succeed_clause({clause, _Line1, [{tuple, _Line2, [_Props, {var, _Line3, Ignored}, _Context]}], _, _}, _State)
  when Ignored == '_';
       Ignored == '_Msg';
       Ignored == 'Event';
       Ignored == '_Other' ->
    undefined;

succeed_clause({clause, _Line1,
                [{tuple, _Line2, [Props, {match, _Line3, {var, _Line4, _}, Event}, Context]}],
                GuardGroups, Body}, State) ->
    succeed_clause({clause, 0, [{tuple, 0, [Props, Event, Context]}], GuardGroups, Body}, State);

succeed_clause({clause, _Line0, Head, GuardGroups, Body}, State) ->
    [{tuple, _Line1, [Props, Event, Context]}] = Head,

    State1 = succeed_head(Props, Event, Context, State),
    State2 = guard_groups(GuardGroups, State1),
    Matches = maps:get(matches, State2),
    State3 = State2#{matches => serialize_matches(Matches)},
    _State4 = lists:foldl(fun search/2, State3, Body).

succeed_head(_Props, Event, Context, State) ->
    {EventString, Matches} = event_tuple_string(Event),
    ContextBin = print(Context),
    State#{event => EventString,
           matches => Matches,
           context => ContextBin,
           sub => <<"">>,
           stage => <<"succeed">>}.

search({lc,_Line,Result,Quals}, State) ->
    State1 = search(Result, State),
    _State2 = lists:foldl(fun lc_bc_qual/2, State1, Quals);
search({bc,Line,E0,Quals}, State) ->
    search({lc, Line, E0, Quals}, State); %% other than 'bc', this is the same as the clause above
search({block,_Line,Expressions}, State) ->
    lists:foldl(fun search/2, State, Expressions);
search({'if',_Line,Clauses}, State) ->
    lists:foldl(fun clause/2, State, Clauses);
search({'case',_Line,Expression,Clauses}, State) ->
    State1 = search(Expression, State),
    _State2 = lists:foldl(fun case_clause/2, State1, Clauses);
search({'receive',_Line,Clauses}, State) ->
    lists:foldl(fun clause/2, State, Clauses);
search({'receive',_Line,Clauses,AfterWait,AfterExpressions}, State) ->
    State1 = lists:foldl(fun clause/2, State, Clauses),
    State2 = search(AfterWait, State1),
    _State3 = lists:foldl(fun search/2, State2, AfterExpressions);
search({'try',_Line,Expressions,_WhatIsThis,CatchClauses,AfterExpressions}, State) ->
    State1 = lists:foldl(fun search/2, State, Expressions),
    State2 = lists:foldl(fun catch_clause/2, State1, CatchClauses),
    _State3 = lists:foldl(fun search/2, State2, AfterExpressions);

search({'fun',_Line,Body}, State) ->
    case Body of
        {clauses,Clauses} ->
            Fun = fun(Clause, State_) -> clause('', Clause, State_) end,
            lists:foldl(Fun, State, Clauses);
        _ ->
            State
    end;
search({call, _Line,
      {remote, _RemLine,
       {atom, _AtomLine, egre_object},
       {atom, _FunAtomLine, attempt}},
      [_Target, NewEvent]},
     State) ->
    State#{new_event_arg => NewEvent};

search({call, _Line,
      {remote, _RemLine,
       {atom, _AtomLine, egre_object},
       {atom, _FunAtomLine, attempt_after}},
      [_, _, Arg3]}, State) ->
    State#{new_event => Arg3};

search({call,_Line,__Fun, _Args}, State) ->
    % Don't care about non-event calls
    State;
search({'catch',_Line,Expression}, State) ->
    %% No new variables added.
    search(Expression, State);

search({match, _Line, {var, _Line1, Var}, NewEvent = {tuple, _, _}}, State)
  when Var == 'Event';
       Var == 'NewEvent' ->
    {EventString, _Matches} = event_tuple_string(NewEvent),
    State#{new_event_tuples => [EventString]};
search({match, _Line, {var, _Lv, 'Event'}, {'case', _Lc, _, Clauses}}, State) ->
    Tuples = [T || {clause, _, _, _, [T]} <- Clauses],
    StringsAndMatches = [event_tuple_string(T) || T <- Tuples],
    {Strings, _} = lists:unzip(StringsAndMatches),
    State#{new_event_tuples => Strings};

search({match, _Line, {var, _Line1, 'Result'}, Result}, State) ->
    State#{result => Result};

search({match,_Line,Expr1,Expr2}, State) ->
    State1 = search(Expr1, State),
    search(Expr2, State1);

search({op,_Line,'==',L,R}, State) ->
    State1 = search(L, State),
    search(R, State1);

search({op, _Line, _Op, L, R}, State) ->
    State1 = search(L, State),
    _State2 = search(R, State1);

%% TODO this is now handled in a #result{} record
search({tuple, _Line0, [{atom, _Line1, resend}, Source, {var, _Line2, 'NewMessage'}]}, State = #{new_message := NewMessage}) ->
    State1 = search(Source, State),
    State1#{resent_message => NewMessage};

%% TODO this is now handled in a #result{} record
search({tuple, _Line0, [{atom, _Line1, broadcast}, {var, _Line2, 'NewMessage'}]}, State = #{new_message := NewMessage}) ->
    {[], State#{broadcast_message => NewMessage}};

search({tuple,_Line, TupleExpressions}, State) ->
    lists:foldl(fun search/2, State, TupleExpressions);
%% There's a special case for all cons's after the first: {tail, _}
%% so this is a list of one item.
search({cons,_Line,Head,{nil, _}}, State) ->
    search(Head, State);
search({cons,_Line,Head,{var, _Line2, '_'}}, State) ->
    search(Head, State);
search(_Cons = {cons,_Line,Head,Tail}, State) ->
    State1 = search(Head, State),
    _State2 = search(Tail, State1);
search(_Tail = {tail, {cons, _Line, Head, {nil, _}}}, State) ->
    search(Head, State);
search(_Tail_ = {tail, {cons, _Line, Head, Tail}}, State) ->
    State1 = search(Head, State),
    _State2 = search(Tail, State1);
search({tail, Call = {call, _Line, _Fun, _Args}}, State) ->
     search(Call, State);
search({tail, Tail}, State) ->
    search(Tail, State);
search({record, _Line, result, ExprFields}, State) ->
    lists:foldl(fun result_field/2, State, ExprFields);
search({record, _Line, _Name, ExprFields}, State) ->
    lists:foldl(fun expr_field/2, State, ExprFields);

search({record_index,_Line, _Name, Field}, State) ->
     search(Field, State);
search({record_field,_Line,Expression, _RecName, Field}, State) ->
    State1 = search(Expression, State),
    _State2 = search(Field, State1);

% How does this happen? (Foo).bar ?
%search({record_field,Line,Rec0,Field0}) ->
    %Rec1 = search(Rec0),
    %Field1 = search(Field0);
search(_IgnoredExpr, State) ->
    State.

catch_clause({clause, _Line0, Exception, GuardGroups, Body}, State) ->
    [{tuple, _Line1, [Class, ExceptionPattern, _Wild]}] = Exception,
    State1 = search(Class, State),
    State2 = search(ExceptionPattern, State1),
    State3 = guard_groups(GuardGroups, State2),
    _State4 = lists:foldl(fun search/2, State3, Body).

clause({clause, _Line, Head, GuardGroups, Body}, State) ->
    clause(ignored, {clause, _Line, Head, GuardGroups, Body}, State).

clause(_Name, {clause, _Line, _Head, _GuardGroups, Body}, State) ->
    % Don't look at function arguments and guards that aren't attempt or succeed
    % but do look for any calls to egre_object:attempt/2 calls
   lists:foldl(fun search/2, State, Body).

case_clause({clause, _Line, [Head], _GuardGroups, Body}, State) ->
    State1 = search(Head, State),
    _State2 = lists:foldl(fun search/2, State1, Body).


result_field({record_field, _Lf, {atom, _La, result}, ResultValue}, State) ->
    result(ResultValue, State);
result_field({record_field, _Lf, {atom, _La, subscribe}, {atom, _La2, Bool}}, State) when is_boolean(Bool) ->
    State#{sub => atom_to_binary(Bool)};
result_field({record_field, _Lf, {atom, _La, event}, NewEvent}, State) ->
    State#{new_event_type => modify,
           new_event_var => NewEvent};
result_field({record_field, _Lf, {atom, _La, context}, Context}, State) ->
    State#{context => Context};
result_field({record_field, _Lf, _, _}, State) ->
    State.

result({atom, _La, succeed}, State) ->
    State#{result => succeed};
result({tuple, _L, [{atom, _La, fail}, _Reason]}, State) ->
    State#{result => fail};
result({var, _Lv, 'Result'}, State = #{result := Result}) ->
    result(Result, State);
result({tuple, _L, [{atom, _La, resend}, _, {var, _Lv, Var}]}, State)
  when Var == 'Event'; Var == 'NewEvent' ->
    State#{result => resend,
           new_event_type => resend};
result({tuple, _L, [{atom, _La, resend}, _, Tuple = {tuple, _Lt, _}]}, State) ->
    {Event, _} = event_tuple_string(Tuple),
    State#{result => resend,
           new_event_type => resend,
           new_event_tuples => [Event]};
result({tuple, _L, [{atom, _La, broadcast}, {var, _Lv, 'NewEvent'}]}, State) ->
    State#{result => broadcast,
           new_event_type => broadcast}.

expr_field({record_field, _Lf, {atom, _La, _F}, Expr}, State) ->
    search(Expr, State);
expr_field({record_field, _Lf, {var,_La,'_'}, Expr}, State) ->
    search(Expr, State).

guard_groups(GuardGroups, State = #{matches := Matches}) ->
    %io:format(user, "GuardGroups = ~p~n", [GuardGroups]),
    GuardGroups2 = [guard_group_conjunction(GG, Matches) || GG <- GuardGroups],
    State#{guard_groups => lists:join(<<", ">>, GuardGroups2)}.

guard_group_conjunction(Guards, Matches) ->
    lists:join(<<", ">>, [guard(Guard, Matches) || Guard <- Guards]).

guard({call, _L, {atom, _La, Fun}, [{var, _Lv, Var}]},
      Matches) ->
    FunBin = atom_to_binary(Fun),
    VarBin = atom_to_binary(Var),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<FunBin/binary, "(", VarBin/binary, ")">>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<FunBin/binary, "(", IndexBin/binary, ")">>
    end;

% {op,{33,13}, '==', {var,{33,8},'Self'}, {call,{33,16},{atom,{33,16},self},[]}},
guard({op, _L, Op, {var, _Lv, Var}, {call, _Lc, {atom, _La, Fun}, []}},
      Matches) ->
    OpBin = atom_to_binary(Op),
    VarBin = atom_to_binary(Var),
    FunBin = atom_to_binary(Fun),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<VarBin/binary, " ", OpBin/binary, " ", FunBin/binary, "()">>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " ", OpBin/binary, " ", FunBin/binary, "()">>
    end;

guard({op, _L, Op, {call, _Lc, {atom, _La, Fun}, []}, {var, _Lv, Var}},
      Matches) ->
    OpBin = atom_to_binary(Op),
    VarBin = atom_to_binary(Var),
    FunBin = atom_to_binary(Fun),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<VarBin/binary, " ", OpBin/binary, " ", FunBin/binary, "()">>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " ", OpBin/binary, " ", FunBin/binary, "()">>
    end;


guard({op, _L, Op, {var, _Lv1, Var1}, {var, _Lv2, Var2}},
      Matches) ->
    OpBin = atom_to_binary(Op),
    Var1Bin = atom_to_binary(Var1),
    Var2Bin = atom_to_binary(Var2),

    MaybeIndex1 = to_bin(maps:get(Var1Bin, Matches, Var1Bin)),
    MaybeIndex2 = to_bin(maps:get(Var2Bin, Matches, Var2Bin)),
    <<MaybeIndex1/binary, " ", OpBin/binary, " ", MaybeIndex2/binary, "()">>;

% {op,{34,20}, '==', {var,{34,8},'HitOrEffect'}, {atom,{34,23},hit}},
% {op,{34,40}, '==', {var,{34,28},'HitOrEffect'}, {atom,{34,43},effect}}
guard({op, _L, Op, {var, _Lv, Var}, {atom, _La, Atom}},
      Matches) ->
    OpBin = atom_to_binary(Op),
    VarBin = atom_to_binary(Var),
    AtomBin = atom_to_binary(Atom),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<VarBin/binary, " ", OpBin/binary, " ", AtomBin/binary>>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " ", OpBin/binary, " ", AtomBin/binary>>
    end;

guard({op, _L, Op, {var, _Lv, Var}, {integer, _La, Int}},
      Matches) ->
    OpBin = atom_to_binary(Op),
    VarBin = atom_to_binary(Var),
    IntBin = integer_to_binary(Int),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<VarBin/binary, " ", OpBin/binary, " ", IntBin/binary>>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " ", OpBin/binary, " ", IntBin/binary>>
    end;

% {op,{34,27}, 'orelse',
%      {op,{34,20},'==',{var,{34,8},'HitOrEffect'},{atom,{34,23},hit}},
%      {op,{34,46},'==',{var,{34,34},'HitOrEffect'},{atom,{34,49},effect}}}
guard({op, _L, Op, Op1, Op2}, Matches) ->
    OpBin = atom_to_binary(Op),
    Op1Bin = guard(Op1, Matches),
    Op2Bin = guard(Op2, Matches),
    <<"(", Op1Bin/binary, " ", OpBin/binary, " ", Op2Bin/binary, ")">>.

to_bin(Int) when is_integer(Int) ->
    integer_to_binary(Int);
to_bin(Bin) when is_binary(Bin) ->
    Bin.

%% This is a list of generators _or_ filters
%% which are simply expressions
%% A generator is a target and a source
lc_bc_qual({generate,_Line,Target,Source}, State) ->
    lists:foldl(fun search/2, State, [Target, Source]);
lc_bc_qual({b_generate,_Line,Target,Source}, State) ->
    lists:foldl(fun search/2, State, [Target, Source]);
lc_bc_qual(FilterExpression, State) ->
    search(FilterExpression, State).

event_tuple_string({match, _L, _var, Tuple}) ->
    event_tuple_string(Tuple);
event_tuple_string({tuple, _L, Elements}) ->
    {Parts, Matches} = event_tuple_string(Elements, 1, [], #{}),
    Parts2 = lists:join(",", Parts),
    {Parts2, Matches}.

event_tuple_string([], _Index, Strings, Matches) ->
    {Strings, Matches};
event_tuple_string([{var, _, '_'} | Rest], Index, Parts, Matches) ->
    Parts2 = Parts ++ [integer_to_binary(Index)],
    event_tuple_string(Rest, Index + 1, Parts2, Matches);
event_tuple_string([{var, _, Var} | Rest], Index, Parts, Matches) ->
    Parts2 = Parts ++ [integer_to_binary(Index)],
    Matches2 = Matches#{atom_to_binary(Var) => Index},
    event_tuple_string(Rest, Index + 1, Parts2, Matches2);
event_tuple_string([{atom, _, Atom} | Rest], Index, Parts, Matches) ->
    Parts2 = Parts ++ [atom_to_binary(Atom)],
    event_tuple_string(Rest, Index, Parts2, Matches);
event_tuple_string([_ | Rest], Index, Parts, Matches) ->
    Parts2 = Parts ++ [integer_to_binary(Index)],
    event_tuple_string(Rest, Index + 1, Parts2, Matches).

map({var, _L, '_'}, _Matches) ->
    <<>>;
map({map, _Lm, MapFields}, Matches) ->
    [map_field(MapField, Matches) || MapField <- MapFields].

map_field({map_field_exact, _Lm, {atom, _La, Field}, {var, _Lv, Var}},
          Matches) ->
    FieldBin = atom_to_binary(Field),
    VarBin = atom_to_binary(Var),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<FieldBin/binary, " == ", VarBin/binary>>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " == ", FieldBin/binary>>
    end;
map_field({map_field_exact, _Lm, {atom, _La1, Field}, {atom, _La2, Atom}}, _) ->
    FieldBin = atom_to_binary(Field),
    AtomBin = atom_to_binary(Atom),
    <<FieldBin/binary, " == ", AtomBin/binary>>;
map_field({map_field_exact, _Lm,
           {atom, _La, Field},
           {tuple, _Lt, [{var, _Lv1, Var},
                         {var, _Lv2, '_'}]}},
          Matches) ->
    FieldBin = atom_to_binary(Field),
    VarBin = atom_to_binary(Var),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<FieldBin/binary, " == ", VarBin/binary>>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " == ", FieldBin/binary>>
    end;
map_field({map_field_exact, _Lm,
           {atom, _La, Field},
           {tuple, _Lt, [_,
                         _,
                         {var, _Lv3, Var},
                         _]}},
          Matches) ->
    FieldBin = atom_to_binary(Field),
    VarBin = atom_to_binary(Var),
    case maps:get(VarBin, Matches, undefined) of
        undefined ->
            <<FieldBin/binary, " == ", VarBin/binary>>;
        Index when is_integer(Index) ->
            IndexBin = integer_to_binary(Index),
            <<IndexBin/binary, " == ", FieldBin/binary>>
    end.

print({var, _Line, VarName}) ->
    move_leading_underscore(a2b(VarName));

print({atom, _Line, Atom}) ->
    a2b(Atom);

print({integer, _Line, Int}) ->
    integer_to_binary(Int);

print({match, _Line, Var, Tuple}) ->
    [print(Var), <<" = ">>, print(Tuple)];

print({record, _Line, RecordName, Fields}) ->
    [<<"#">>, a2b(RecordName), <<"{">> | map_separate(fun print/1, Fields)] ++ [<<"}">>];

print({record_field, _Line, {atom, _Line2, FieldName}, {var, _VarLine, VarName}}) ->
    [a2b(FieldName), <<" = ">>, a2b(VarName)];

print({record_field, _Line, {atom, _Line2, FieldName}, {match, _Line3, Var, Record}}) ->
    [a2b(FieldName), <<" = ">>, print(Var), <<" = ">>, print(Record)];

print({record_field, _Line, {atom, _Line2, FieldName}, Call}) ->
    [a2b(FieldName), <<" = ">>, print(Call)];

print({tuple, _Line, Expressions}) ->
    [<<"{">> | map_separate(fun print/1, Expressions)] ++ [<<"}">>];

print({op, _Line, Operator, Expr1, Expr2}) ->
    [print(Expr1), <<" ">>, a2b(Operator), <<" ">>, print(Expr2)];

print({call, _Line, {atom, _Line2, FunctionName}, Params}) ->
    ParamBins = map_separate(<<", ">>, fun print/1, Params),
    [a2b(FunctionName), <<"(">>, ParamBins, <<")">>];

print({cons, _Line, Var1, Var2}) ->
    [<<"[">>, print(Var1), <<" | ">>, print(Var2), <<"]">>];

print({bin, _Line1, BinElements}) ->
    [print(BinElement) || BinElement <- BinElements];

print({bin_element, _Line1, {string, _Line2, String}, _, _}) ->
    [<<"<<\"">>, list_to_binary(String), <<"\">>">>];

% e.g. Match in binary: e.g. <<Bin/binary>>
print({bin_element, _Line, {var, _line2, Var}, default, [binary]}) ->
    [a2b(Var), <<"/binary">>];

print({map, _Line1, Matches}) ->
    [<<"#{">>, map_separate(fun print/1, Matches), <<"}">>];

print({map_field_exact, _Line1, Key, Val}) ->
    [print(Key), <<" := ">>, print(Val)];

print({nil, _Line}) ->
    <<"[]">>.


%separate(List) when is_list(List) ->
    %separate(<<", ">>, List).

separate(Separator, List) ->
    lists:join(Separator, List).

map_separate(Fun, List) ->
    map_separate(<<", ">>, Fun, List).

map_separate(Separator, Fun, List) ->
    separate(Separator, lists:map(Fun, List)).

a2b(Atom) ->
    list_to_binary(atom_to_list(Atom)).

move_leading_underscore(JustUnderscore = <<$_>>) ->
    JustUnderscore;
move_leading_underscore(<<$_, Rest/binary>>) ->
    <<Rest/binary, "_">>;
move_leading_underscore(Bin) ->
    Bin.
