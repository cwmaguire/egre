-module(egre_protocol_parse_transform).

-export([parse_transform/2]).
-export([inline_form/2]).
-export([body_scope_paths/2]).

%% FIXME
%% rules_attribute_look is not working
%% is_owner/2 and describe/4 are not being inlined

parse_transform(Forms, _Options) ->
    % io:format("egre_protocol_parse_transform - _Options: ~p~n", [_Options]),
    % io:format("a: ~p~n", [?a]),
    PropertyTypeModule = property_type_module(Forms),
    io:format(user, "Property type module: ~p~n", [PropertyTypeModule]),
    PropertyTypes =
        case PropertyTypeModule of
            undefined ->
                [];
            _ ->
             PropertyTypeModule:property_types()
        end,
    io:format(user, "Property types: ~p~n", [PropertyTypes]),
    %egre_dbg:add(egre_protocol_parse_transform, inline_form),
    InlinedApiFunctions = inline_flatten(Forms),
    egre_protocol_event_pairs:extract(InlinedApiFunctions, PropertyTypes),
    %io:format("Forms:~n~p~n", [Forms]),
    Forms.


 % {attribute,
 %  {6,2},
 %  compile,
 %  [{d,property_type_module,mud_util},
 %   {compile_info,[{property_type_module,mud_util}]},
 %   {bad,option}]},

property_type_module([]) ->
    undefined;
property_type_module([{attribute, _, compile, [{property_type_module, Mod} | _]} | _]) ->
    Mod;
property_type_module([_ | Rest]) ->
    property_type_module(Rest).

inline_flatten([FilenameAttribute | Forms]) ->
    FileRoot = filename(FilenameAttribute),
    Module = module(Forms),

    AstFuns = lists:filter(fun is_fun/1, Forms),
    AstFunsStripped = [strip_lines(F) || F <- AstFuns],
    FunKVs = [fun2kv(Module, F) || F <- AstFunsStripped],
    Funs = maps:from_list(FunKVs),
    [_ | _] = ApiFunKVs = lists:filter(fun is_api_fun/1, FunKVs),
    ApiFuns = maps:from_list(ApiFunKVs),

    InlinedFuns = maps:map(fun(K, V) ->
                               inline_api_fun(K, V, Funs)
                           end,
                           ApiFuns),
    io:format(user, "InlinedFuns: ~p~n", [InlinedFuns]),

    [_ | _] = FunClauses = lists:foldl(fun flatten_clauses/2, [], maps:to_list(InlinedFuns)),
    io:format(user, "FunClauses: ~p~n", [FunClauses]),
    [_ | _] = ScopePaths = lists:foldl(fun scope_paths/2, [], FunClauses),
    SortedScopePaths = lists:sort(ScopePaths),

    Path = path(),
    {ok, IO} = file:open(Path ++ "/" ++ FileRoot, [write]),
    FormsIolist = io_lib:format("~p", [SortedScopePaths]),
    file:write(IO, FormsIolist),
    file:close(IO),
    ScopePaths.

flatten_clauses({K, Clauses}, ModuleDisjunctions) ->
    ct:pal("Clauses: ~p~n", [Clauses]),
    ModuleDisjunctionsNew = [{K, SplitConjunction} || Clause <- Clauses,
                                                 Disjunction <- Clause,
                                                 SplitConjunction <- Disjunction],
    ModuleDisjunctions ++ ModuleDisjunctionsNew.

is_fun({function, _Line, _Name, _Arity, _Clauses}) ->
    true;
is_fun(_) ->
    false.

is_api_fun({{_Mod, attempt, 1}, _}) ->
    true;
is_api_fun({{_Mod, succeed, 1}, _}) ->
    true;
is_api_fun(_) ->
    false.

fun2kv(Module, {function, Name, Arity, Clauses}) ->
    {{Module, Name, Arity}, Clauses}.

%% Must return [[[<clause, ...]]]

inline_api_fun({Module, _, _}, Clauses, Funs) ->
    [inline_api_clause(Module, C, Funs) || C <- Clauses].

inline_api_clause(Module, {clause, Args, [], Forms}, Funs) ->
    [inline_api_conjunction(Module, {clause, Args, [], Forms}, Funs)];
inline_api_clause(Module, {clause, Args, Disjunction, Forms}, Funs) ->
    io:format(user, "Disjunction: ~p~n", [Disjunction]),
    [inline_api_conjunction(Module,
                            {clause, Args, Conjunction, Forms},
                            Funs) || Conjunction <- Disjunction].

inline_api_conjunction(Module, {clause, Args, [], Forms}, Funs) ->
    [inline_api_conjunction_branches(Module, {clause, Args, [], Forms}, Funs)];
inline_api_conjunction(Module, {clause, Args, GuardExpressions, Forms}, Funs) ->
    GuardBranches = flatten_guard_branches(GuardExpressions, [[]]),
    [inline_api_conjunction_branches(Module,
                                     {clause, Args, [Branch], Forms},
                                     Funs) || Branch <- GuardBranches].

flatten_guard_branches([], Conjunctions) ->
    Conjunctions;
flatten_guard_branches([{op, 'andalso', Expression1, Expression2} | Rest], Conjunctions) ->
    Branches1 = flatten_guard_branches([Expression1], [[]]),
    Branches2 = flatten_guard_branches([Expression2], [[]]),
    NewBranches = [{op, 'andalso', B1, B2} || [B1] <- Branches1, [B2] <- Branches2],
    NewConjunctions = [C ++ B || C <- Conjunctions, B <- NewBranches],
    flatten_guard_branches(Rest, NewConjunctions);
flatten_guard_branches([{op, 'orelse', Expression1, Expression2} | Rest], Conjunctions) ->
    io:format(user, "orelse exp1: ~p~n", [Expression1]),
    io:format(user, "orelse exp2: ~p~n", [Expression2]),
    Branches1 = flatten_guard_branches([Expression1], [[]]),
    Branches2 = flatten_guard_branches([Expression2], [[]]),
    io:format(user, "Orelse Branch1: ~p~n"
                    "Orelse Branch2: ~p~n",
                    [Branches1, Branches2]),
    % NewBranches = [{op, 'orelse', B1, B2} || B1 <- Branches1, B2 <- Branches2],
    % io:format(user, "New orelse branches: ~p~n", [NewBranches]),
    LeftConjunctions = [C ++ B || C <- Conjunctions, B <- Branches1],
    RightConjunctions = [C ++ B || C <- Conjunctions, B <- Branches2],
    NewConjunctions = LeftConjunctions ++ RightConjunctions,
    io:format(user, "New conjunctions with orelse tails: ~p~n", [NewConjunctions]),
    flatten_guard_branches(Rest, NewConjunctions);
% flatten_guard_branches([Expression | Rest], []) ->
%     flatten_guard_branches(Rest, [Expression]);
flatten_guard_branches([Expression | Rest], Conjunctions) ->
    flatten_guard_branches(Rest, [C ++ [Expression] || C <- Conjunctions]).

inline_api_conjunction_branches(Module, {clause, Args, ConjunctionBranch, Forms}, Funs) ->
    % TODO this seems like a no-op
    Disjunction =
        case ConjunctionBranch of
            [] ->
                [];
            _ ->
                ConjunctionBranch
        end,
    io:format(user, "Disjunction: ~p~n", [Disjunction]),
    {Module, Forms2, _Funs, _} =
        lists:foldl(fun inline_form/2,
                    {Module, _Forms = [], Funs, []},
                    Forms),
        {clause, Args, Disjunction, Forms2}.

inline_form(Form = {call, {atom, ErlangFun}, _CallArgs},
            {Module, Forms, Funs, InlinedFuns})
  when ErlangFun == throw;
       ErlangFun == self;
       ErlangFun == integer_to_binary;
       ErlangFun == make_ref;
       ErlangFun == atom_to_binary;
       ErlangFun == min;
       ErlangFun == tuple_to_list;
       ErlangFun == list_to_tuple ->
    {Module, Forms ++ [Form], Funs, InlinedFuns};
inline_form(Form = {call, {atom, FunName}, CallArgs},
            {Module, Forms, Funs, InlinedFuns}) ->

    case lists:member(FunName, InlinedFuns) of
        false ->
            InlinedFuns2 = [FunName | InlinedFuns],

            {Module, ArgForms, _Funs, InlinedFuns3} =
                lists:foldl(fun inline_form/2,
                            {Module, [], Funs, InlinedFuns2},
                            CallArgs),

            Arity = length(CallArgs),
            Clauses = maps:get({Module, FunName, Arity}, Funs),
            {Module, Clauses2, _Funs2, InlinedFuns4} =
                lists:foldl(fun inline_clause/2,
                            {Module, [], Funs, InlinedFuns3},
                            Clauses),

            Case = {'case', {tuple, ArgForms}, Clauses2},
            {Module, Forms ++ [Case], Funs, InlinedFuns4};
        true ->
            {Module, Forms ++ [Form], Funs, InlinedFuns}
    end;

inline_form({lc, Body, Generators},
            {Module, Forms, Funs, InlinedFuns}) ->
    {Module, [BodyForm], _, InlinedFuns2} =
        inline_form(Body, {Module, [], Funs, InlinedFuns}),

    {Module, GeneratorForms, _, InlinedFuns3} =
        lists:foldl(fun inline_lc_expression/2,
                    {Module, [], Funs, InlinedFuns2},
                    Generators),

    LC = {lc, BodyForm, GeneratorForms},
    {Module, Forms ++ [LC], Funs, InlinedFuns3};

inline_form({'case', Expression, Clauses},
            {Mod, Forms, Funs, InlinedFuns}) ->

    {Mod, [InlinedExpression], _, InlinedFuns2} =
        inline_form(Expression, {Mod, [], Funs, InlinedFuns}),

    {Module, Clauses2, _Funs2, InlinedFuns3} =
        lists:foldl(fun inline_case_clause/2,
                    {Mod, [], Funs, InlinedFuns2},
                    Clauses),

    Case = {'case', InlinedExpression, Clauses2},
    {Module, Forms ++ [Case], Funs, InlinedFuns3};

inline_form({tuple, Elements}, {Module, Forms, Funs, InlinedFuns}) ->
    {Module, SubForms2, _Funs, InlinedFuns2} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, InlinedFuns},
                    Elements),
    Form2 = {tuple, SubForms2},
    {Module, Forms ++ [Form2], Funs, InlinedFuns2};
inline_form(Form, {Module, Forms, Funs, InlinedFuns})
  when is_tuple(Form) ->
    SubForms = tuple_to_list(Form),

    {Module, SubForms2, _Funs, InlinedFuns2} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, InlinedFuns},
                    SubForms),
    Form2 = list_to_tuple(SubForms2),
    {Module, Forms ++ [Form2], Funs, InlinedFuns2};
inline_form(Form, {Module, Forms, Funs, InlinedFuns}) ->
    {Module, Forms ++ [Form], Funs, InlinedFuns}.

inline_lc_expression({generate, Bindings, Expression},
                    {Module, Forms, Funs, InlinedFuns}) ->
    {Module, [Expression2], _Funs, InlinedFuns2} =
        inline_form(Expression, {Module, [], Funs, InlinedFuns}),
    Generator = {generate, Bindings, Expression2},
    {Module, Forms ++ [Generator], Funs, InlinedFuns2};
inline_lc_expression(Form,
                    {Module, Forms, Funs, InlinedFuns}) ->
    {Module, Forms ++ [Form], Funs, InlinedFuns}.

inline_clause({clause, Args, Guards, Body},
              {Module, Forms, Funs, InlinedFuns}) ->
    Args2 = [{tuple, Args}],
    {Module, Body2, _Funs, InlinedFuns2} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, InlinedFuns},
                    Body),
    Clauses =
        case Guards of
            [] ->
                [{clause, Args2, Guards, Body2}];
            _ ->
                [{clause, Args2, Conjunction, Body2} || Conjunction <- Guards]
        end,
    %Clause = {clause, Args2, Guards, Body2},
    {Module, Forms ++ Clauses, Funs, InlinedFuns2}.

inline_case_clause({clause, Expression, Guards, Body},
                   {Module, Forms, Funs, InlinedFuns}) ->
    {Module, Body2, _Funs, InlinedFuns2} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, InlinedFuns},
                    Body),
    Clauses =
        case Guards of
            [] ->
                [{clause, Expression, Guards, Body2}];
            _ ->
                [{clause, Expression, Conjunction, Body2} || Conjunction <- Guards]
        end,
    %Clause = {clause, Expression, Guards, Body2},
    {Module, Forms ++ Clauses, Funs, InlinedFuns2}.

scope_paths({K, Clause}, ScopePaths) ->
    ClauseScopePaths = clause_scope_paths(Clause, []),
    NewScopePaths = [{K, ClauseScopePath} || ClauseScopePath <- ClauseScopePaths],
    ScopePaths ++ NewScopePaths.

clause_scope_paths({clause, Head, MaybeGuards, Body}, ScopePaths) ->
    Guards =
        case MaybeGuards of
            [] ->
                [];
            _ ->
                [MaybeGuards]
        end,
    [_ | _] = NewScopePaths = lists:foldl(fun body_scope_paths/2, [], Body),
    ScopePathClauses = [{clause, Head, Guards, ScopePath} || ScopePath <- NewScopePaths],
    ScopePaths ++ ScopePathClauses.

body_scope_paths({'case', Expr, Clauses}, ScopePaths) ->
    [_ | _] = NewExprPaths = lists:foldl(fun body_scope_paths/2, [], [Expr]),
    [_ | _] = NewScopePaths = lists:foldl(fun clause_scope_paths/2, [], Clauses),
    NewCaseScopePaths =
        [[{'case', ExprPath, [NewScopePath]}] || [ExprPath] <- NewExprPaths, NewScopePath <- NewScopePaths],
    case ScopePaths of
        [] ->
            NewCaseScopePaths;
        _ ->
            CartesianProduct =
                [ScopePath ++ NewScopePath || ScopePath <- ScopePaths,
                                              NewScopePath <- NewCaseScopePaths],
            CartesianProduct
    end;
body_scope_paths({tuple, []}, []) ->
    [[{tuple, []}]];
body_scope_paths({tuple, []}, ScopePaths) ->
    [ScopePath ++ [{tuple, []}] || ScopePath <- ScopePaths];
body_scope_paths({tuple, Items}, ScopePaths) ->
    ItemScopePaths = [body_scope_paths(I, []) || I <- Items],
    [_ | _] = ElementLists = lists:foldl(fun cartesian_product/2, [], ItemScopePaths),
    TuplePaths = [[{tuple, Elements}] || Elements <- ElementLists],
    case ScopePaths of
        [] ->
            TuplePaths;
        _ ->
            [ScopePath ++ TuplePath || TuplePath <- TuplePaths, ScopePath <- ScopePaths]
    end;
body_scope_paths({match, Expr1, Expr2}, ScopePaths) ->
    [_ | _] = NewExpr1Paths = lists:foldl(fun body_scope_paths/2, [], [Expr1]),
    [_ | _] = NewExpr2Paths = lists:foldl(fun body_scope_paths/2, [], [Expr2]),
    NewMatchScopePaths =
        [[{match, Expr1Path, Expr2Path}] || [Expr1Path] <- NewExpr1Paths, [Expr2Path] <- NewExpr2Paths],
    case ScopePaths of
        [] ->
            NewMatchScopePaths;
        _ ->
            [ScopePath ++ NewMatchScopePath || ScopePath <- ScopePaths, NewMatchScopePath <- NewMatchScopePaths]
    end;
body_scope_paths(NotCase, []) ->
    [[NotCase]];
body_scope_paths(NotCase, ScopePaths) ->
    [ScopePath ++ [NotCase] || ScopePath <- ScopePaths].

cartesian_product(After, _Acc = []) ->
    After;
cartesian_product(After, Before) ->
    [B ++ A || B <- Before, A <- After].

path() ->
    case os:getenv("EGRE_PARSE_TRANSFORM_OUT_DIR") of
        false ->
            {ok, CWD} = file:get_cwd(),
            CWD;
        Path ->
            Path
    end.

strip_lines({L, C}) when is_integer(L), is_integer(C) ->
    delete_me;
strip_lines(Form) when is_tuple(Form) ->
    List = tuple_to_list(Form),
    Forms2 = [strip_lines(F) || F <- List],
    Forms3 = [F || F <- Forms2, F /= delete_me],
    list_to_tuple(Forms3);
strip_lines(Form) when is_list(Form) ->
    [strip_lines(F) || F <- Form];
strip_lines(Form) ->
    Form.

module([{attribute, _Line, module, Module} | _]) ->
    remove_prefix(<<"rules_">>, atom_to_binary(Module));
module([_ | Forms]) ->
    module(Forms);
module(_) ->
    <<"unknown">>.

remove_prefix(Prefix, Bin) ->
    case Bin of
        <<Prefix:(byte_size(Prefix))/binary, Rest/binary>> ->
            Rest;
        Bin_ when Bin_ == Bin ->
            Bin
    end.

filename({attribute, _L, file, {Filename, _}}) ->
    filename:rootname(filename:basename(Filename)).
