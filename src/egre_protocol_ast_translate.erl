-module(egre_protocol_ast_translate).

-export([parse_transform/2]).

parse_transform(Forms, _Options) ->
    translate_ast(Forms),
    Forms.

translate_ast([FilenameAttribute | Forms]) ->
    FileRoot = filename(FilenameAttribute),

    %io:format(user, "Forms = ~p~n", [Forms]),
    AstFuns = lists:filter(fun is_fun/1, Forms),
    AstFuns2 = [strip_lines(F) || F <- AstFuns],
    FunKVs = lists:map(fun fun2kv/1, AstFuns2),
    Funs = maps:from_list(FunKVs),
    %io:format(user, "Funs = ~p~n", [maps:keys(Funs)]),
    ApiFunKVs = lists:filter(fun is_api_fun/1, FunKVs),
    ApiFuns = maps:from_list(ApiFunKVs),
    %io:format(user, "ApiFuns = ~p~n", [maps:keys(ApiFuns)]),

    ApiFuns2 = maps:map(fun(K, V) ->
                            inline_api_fun(K, V, Funs)
                        end,
                        ApiFuns),
    ApiFuns2,
    Path = path(),
    {ok, IO} = file:open(Path ++ FileRoot, [write]),
    FormsIolist = io_lib:format("~p", [ApiFuns2]),
    file:write(IO, FormsIolist),
    file:close(IO).

is_fun({function, _Line, _Name, _Arity, _Clauses}) ->
    true;
is_fun(_) ->
    false.

is_api_fun({{attempt, 1}, _}) ->
    true;
is_api_fun({{succeed, 1}, _}) ->
    true;
is_api_fun(_) ->
    false.

fun2kv({function, Name, Arity, Clauses}) ->
    {{Name, Arity}, Clauses}.


inline_api_fun(_NameArity, Clauses, Funs) ->
    [inline_api_clause(C, Funs) || C <- Clauses].

inline_api_clause({clause, Args, Guards, Forms}, Funs) ->
    %io:format(user, "Forms = ~p~n", [Forms]),

    {Forms2, _, _, _} =
        lists:foldl(fun inline_api_form/2,
                    {[], Args, Funs, " "},
                    Forms),
        {clause, Args, Guards, Forms2}.


%% This shouldn't happen now that lines are stripped out.
inline_api_form({L, C},
                {Forms, Args, Funs, Indent})
  when is_integer(L),
       is_integer(C) ->
    {Forms ++ [{L, C}], Args, Funs, Indent};
inline_api_form(Self = {call, {atom, self}, []},
                {Forms, Args, Funs, Indent}) ->
    %io:format("~sself()~n", [Indent]),
    {Forms ++ [Self], Args, Funs, Indent};

inline_api_form(RemoteCall =
                    {call,
                     {remote, {atom, _A1}, {atom, _A2}},
                     _CallArgs},
                {Forms, Args, Funs, Indent}) ->
    %Arity = length(CallArgs),
    %io:format("~s~p:~p/~p(~p)~n", [Indent, A1, A2, Arity, CallArgs]),

    {Forms ++ [RemoteCall], Args, Funs, Indent};

%% TODO case statements are basically function calls and their expressions can contain
%% arbitrary forms including and containing function calls. I need to do the same thing
%% with a case statement as I do with a function call, except I don't need to update the arguments
%% of the case statement expressions.
inline_api_form({match,
                 Var,
                 {'case', LocalCall = {call, _, {atom, _, _}, _Args}, Clauses}},
                {Forms, Args, Funs, Indent}) ->

    {BeforeForms, FunVar, _, _} = inline_api_form(LocalCall, {Forms, undefined, Funs, Indent}),

    NewCase = {'case', {var, FunVar}, Clauses},
    NewMatch = {match, Var, NewCase},
    {Forms ++ BeforeForms ++ [NewMatch], Args, Funs, Indent};


inline_api_form({call, {atom, FunName}, CallArgs},
                {Forms, Args, Funs, Indent}) ->

    {BeforeArgBlocks, ArgForms, _, _, _, _} =
        lists:foldl(fun inline_args/2,
                    {_BeforeArgBlocks = [], _ArgForms = [], _NewArgs = [], Args, Funs, Indent},
                    CallArgs),

    %io:format(user, "BeforeArgBlocks = ~p~n", [BeforeArgBlocks]),
    %io:format(user, "ArgForms = ~p~n", [ArgForms]),

    Arity = length(CallArgs),
    %io:format("~sGetting fun for ~p/~p~n", [Indent, FunName, Arity]),

    Clauses = maps:get({FunName, Arity}, Funs),

    {BeforeCallBlocks, Clauses2, _, _, _} =
        lists:foldl(fun inline_fun_clause/2,
                    {[], [], ArgForms, Args, Funs, Indent},
                    Clauses),

    %io:format(user, "BeforeCallBlocks = ~p~n", [BeforeCallBlocks]),
    %io:format(user, "Clauses2 = ~p~n", [Clauses2]),

    Block =
        case Clauses of
            [{clause, _, [], [], Forms_}] ->
                {block, Forms_};
            _ ->
                {'case', {tuple, ArgForms}, Clauses2}
        end,
    FunVar = atom2var(FunName),
    Match = {match, {var, FunVar}, Block},


    {Forms ++ BeforeArgBlocks ++ BeforeCallBlocks ++ [Match],
     FunVar,
     Funs,
     Indent};


inline_api_form(T, {Forms, Args, Funs, Indent}) when is_tuple(T) ->
    _E1 = element(1, T),
    %io:format(user, "~s{~p, ...}~n", [Indent, E1]),

    List = tuple_to_list(T),
    {Forms2, _, _, _} =
        lists:foldl(fun inline_api_form/2,
                    {[], Args, Funs, Indent ++ "    "},
                    List),
    Tuple = list_to_tuple(Forms2),
    {Forms ++ [Tuple], Args, Funs, Indent};
inline_api_form(L = [_H | _], {Forms, Args, Funs, Indent}) ->
    %io:format(user, "~s[~p | _]~n", [Indent, H]),
    {Forms ++ [L], Args, Funs, Indent};
inline_api_form(Other, {Forms, Args, Funs, Indent}) ->
    %io:format(user, "~s|~p~n", [Indent, Other]),
    {Forms ++ [Other], Args, Funs, Indent}.

%% TODO handle function calls in arguments: inline the calls
%% and put them in PreForms, then replace the arg with the
%% variable the block is assigned to
inline_args(SimpleArg = {var, Atom},
            {PreForms, Forms, NewArgs, Args, Funs, Indent})
  when is_atom(Atom) ->
    %io:format("~s SimpleArg: ~p~n", [Indent, Atom]),
    {PreForms, Forms ++ [SimpleArg], NewArgs, Args, Funs, Indent};
inline_args(Arg,
            {PreForms, Forms, Args, Funs, Indent}) ->
    %io:format(user, "~sArg: ~p~n", [Indent, Arg]),
    {PreForms, Forms ++ [Arg], [], Args, Funs, Indent}.

inline_fun_clause({clause, OldArgs, Guards, Body},
                  {PreForms, ClauseForms, NewArgNames, Args, Funs, Indent}) ->

    OldArgNames = [Atom || {var, Atom} <- OldArgs],
    ArgPairs = lists:zip(OldArgs, NewArgNames),
    Args2 = [{var, New} || {{var, _Old}, New} <- ArgPairs],

    RenamedArgMap =
        lists:foldl(fun map_arg_changes/2,
                    #{},
                    lists:zip(OldArgNames, NewArgNames)),

    {Guards2, _} =
        lists:foldl(fun rename_form_args/2,
                    {[], RenamedArgMap},
                    Guards),
    %io:format(user, "Guards = ~p~n", [Guards]),
    %io:format(user, "Guards2 = ~p~n", [Guards2]),

    Body2 =
        lists:foldl(fun rename_form_args/2,
                    {[], RenamedArgMap},
                    Body),

    Clause2 = {clause, Args2, Guards2, Body2},

    {PreForms, ClauseForms ++ [Clause2], Args, Funs, Indent}.

map_arg_changes({Arg, Arg}, Map) ->
    Map;
map_arg_changes({OldArg, NewArg}, Map) ->
    Map#{OldArg => NewArg}.

rename_form_args(Form, {Forms, ArgMap}) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    %io:format(user, "List = ~p~n", [List]),
    {Forms2, _ArgMap} =
        lists:foldl(fun rename_form_args/2,
                    {[], ArgMap},
                    List),
    Tuple = list_to_tuple(Forms2),
    {Forms ++ [Tuple], ArgMap};
rename_form_args(Form, {Forms, ArgMap}) when is_list(Form) ->
    {Forms2, _ArgMap} =
        lists:foldl(fun rename_form_args/2,
                    {[], ArgMap},
                    Form),
    {Forms ++ Forms2, ArgMap};
rename_form_args({var, Var}, {Forms, ArgMap}) ->
    NewForm =
        case ArgMap of
            #{Var := NewVar} ->
                {var, NewVar};
            _ ->
                {var, Var}
        end,
    {Forms ++ [NewForm], ArgMap};
rename_form_args(Form, {Forms, ArgMap}) ->
    {Forms ++ [Form], ArgMap}.

atom2var(Atom) ->
    [First | Rest] = atom_to_list(Atom),
    [Upper] = string:uppercase([First]),
    [Upper | Rest].

filename({attribute, _L, file, {Filename, _}}) ->
    filename:rootname(filename:basename(Filename)).

path() ->
    case os:getenv("EGRE_PARSE_TRANSFORM_OUT_DIR") of
        false ->
            {ok, CWD} = file:get_cwd(),
            CWD;
        Path ->
            Path
    end.

strip_lines({L, C}) when is_integer(L), is_integer(C) ->
    %ct:pal("~p:~p: {~p, ~p}~n", [?MODULE, ?FUNCTION_NAME, L, C]),
    delete_me;
strip_lines(Form) when is_tuple(Form) ->
    %ct:pal("~p:~p: Form~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Form]),
    List = tuple_to_list(Form),
    %io:format(user, "List = ~p~n", [List]),
    Forms2 = [strip_lines(F) || F <- List],
    Forms3 = [F || F <- Forms2, F /= delete_me],
    list_to_tuple(Forms3);
strip_lines(Form) when is_list(Form) ->
    ct:pal("~p:~p: List Form~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Form]),
    io:format("List form: ~p~n", [Form]),
    [strip_lines(F) || F <- Form];
strip_lines(Form) ->
    %ct:pal("~p:~p: Form~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Form]),
    Form.
