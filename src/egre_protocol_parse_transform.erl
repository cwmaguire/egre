-module(egre_protocol_parse_transform).

-export([parse_transform/2]).

parse_transform(Forms, _Options) ->
    InlinedApiFunctions = translate_ast(Forms),
    egre_protocol_event_chains:extract(InlinedApiFunctions),
    Forms.

translate_ast([FilenameAttribute | Forms]) ->
    FileRoot = filename(FilenameAttribute),
    Module = module(Forms),

    AstFuns = lists:filter(fun is_fun/1, Forms),
    AstFuns2 = [strip_lines(F) || F <- AstFuns],
    FunKVs = lists:map(fun(Fun) ->
                               fun2kv(Module, Fun)
                       end,
                       AstFuns2),
    Funs = maps:from_list(FunKVs),
    ApiFunKVs = lists:filter(fun is_api_fun/1, FunKVs),
    ApiFuns = maps:from_list(ApiFunKVs),

    InlinedFuns = maps:map(fun(K, V) ->
                               inline_api_fun(K, V, Funs)
                           end,
                           ApiFuns),

    FunClauses = lists:foldl(fun flatten_clauses/2, [], maps:to_list(InlinedFuns)),
    % all of the scope paths, or all of the fun clause-guards, need to be siblings, which means we
    % need to add them all to the same list
    ScopePaths = lists:foldl(fun scope_paths/2, [], FunClauses),
    SortedScopePaths = lists:sort(ScopePaths),


    Path = path(),
    {ok, IO} = file:open(Path ++ "/" ++ FileRoot, [write]),
    FormsIolist = io_lib:format("~p", [SortedScopePaths]),
    file:write(IO, FormsIolist),
    file:close(IO),
    ScopePaths.

flatten_clauses({K, Clauses}, ModuleDisjunctions) ->
    ModuleDisjunctionsNew = [{K, Disjunction} || Clause <- Clauses, Disjunction <- Clause],
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


inline_api_fun({Module, _, _}, Clauses, Funs) ->
    [inline_api_clause(Module, C, Funs) || C <- Clauses].

inline_api_clause(Module, {clause, Args, [], Forms}, Funs) ->
    [inline_api_disjunction(Module, {clause, Args, [], Forms}, Funs)];
inline_api_clause(Module, {clause, Args, Guards, Forms}, Funs) ->
    [inline_api_disjunction(Module,
                            {clause, Args, Conjunction, Forms},
                            Funs) || Conjunction <- Guards].

inline_api_disjunction(Module, {clause, Args, MaybeConjunction, Forms}, Funs) ->
    Disjunction =
        case MaybeConjunction of
            [] ->
                [];
            _ ->
                [MaybeConjunction]
        end,
    {Module, Forms2, _Funs, _} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, []},
                    Forms),
        {clause, Args, Disjunction, Forms2}.

inline_form(Form = {call, {atom, throw}, _CallArgs},
            {Module, Forms, Funs, InlinedFuns}) ->
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
        lists:foldl(fun inline_lc_generator/2,
                    {Module, [], Funs, InlinedFuns2},
                    Generators),

    LC = {lc, BodyForm, GeneratorForms},
    {Module, Forms ++ [LC], Funs, InlinedFuns3};

inline_form(Form, {Module, Forms, Funs, InlinedFuns}) ->
    timer:sleep(20),
    {Module, Forms ++ [Form], Funs, InlinedFuns}.

inline_lc_generator({generate, Bindings, Expression},
                    {Module, Forms, Funs, InlinedFuns}) ->
    {Module, [Expression2], _Funs, InlinedFuns2} =
        inline_form(Expression, {Module, [], Funs, InlinedFuns}),
    Generator = {generate, Bindings, Expression2},
    {Module, Forms ++ [Generator], Funs, InlinedFuns2}.

inline_clause({clause, Args, Guards, Body},
              {Module, Forms, Funs, InlinedFuns}) ->
    Args2 = [{tuple, Args}],
    {Module, Body2, _Funs, InlinedFuns2} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, InlinedFuns},
                    Body),
    Clause = {clause, Args2, Guards, Body2},
    {Module, Forms ++ [Clause], Funs, InlinedFuns2}.

% clause({clause,Anno,H0,G0,B0}) ->
%     H1 = head(H0),
%     G1 = guard(G0),
%     B1 = exprs(B0),
%     {clause,H1,G1,B1}.

% [{clause,[{integer,1}],[],[{atom,ok}]},[]],

scope_paths({K, Clause}, ScopePaths) ->
    ClauseScopePaths = clause_scope_paths(Clause, []),
    NewScopePaths = [{K, ClauseScopePath} || ClauseScopePath <- ClauseScopePaths],
    ScopePaths ++ NewScopePaths.

clause_scope_paths({clause, Head, Guards, Body}, ScopePaths) ->
    NewScopePaths = lists:foldl(fun body_scope_paths/2, [], Body),
    ScopePathClauses =
        case Guards of
            [] ->
                [{clause, Head, [], ScopePath} || ScopePath <- NewScopePaths];
            _ ->
                CartesianProduct = [{Guard, ScopePath} || Guard <- Guards,
                                                          ScopePath <- NewScopePaths],
                [{clause, Head, [Guard], ScopePath} || {Guard, ScopePath} <- CartesianProduct]
        end,
    ScopePaths ++ ScopePathClauses.

% {'case', E0, Cs0} ->
%     Cs1 = icr_clauses(Cs0),
%     {'case',Anno,E1,Cs1};

% icr_clauses([C0|Cs]) ->
%     C1 = clause(C0),
%     [C1|icr_clauses(Cs)];
% icr_clauses([]) -> [].

% clause({clause,H0,G0,B0}) ->
%     H1 = head(H0),
%     G1 = guard(G0),
%     B1 = exprs(B0),
%     {clause,H1,G1,B1}.

body_scope_paths({'case', Expr, Clauses}, ScopePaths) ->
    NewScopePaths = lists:foldl(fun clause_scope_paths/2, [], Clauses),
    NewCaseScopePaths =
        [[{'case', Expr, [NewScopePath]}] || NewScopePath <- NewScopePaths],
    case ScopePaths of
        [] ->
            NewCaseScopePaths;
        _ ->
            CartesianProduct =
                [ScopePath ++ NewScopePath || ScopePath <- ScopePaths,
                                              NewScopePath <- NewCaseScopePaths],
            CartesianProduct
    end;
body_scope_paths(NotCase, []) ->
    [[NotCase]];
body_scope_paths(NotCase, ScopePaths) ->
    [ScopePath ++ [NotCase] || ScopePath <- ScopePaths].

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
        <<Prefix:(size(Prefix))/binary, Rest/binary>> ->
            Rest;
        Bin_ when Bin_ == Bin ->
            Bin
    end.

filename({attribute, _L, file, {Filename, _}}) ->
    filename:rootname(filename:basename(Filename)).
