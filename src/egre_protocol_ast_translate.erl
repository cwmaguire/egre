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

    {Forms2, _Funs} =
        lists:foldl(fun inline_form/2,
                    {[], Funs},
                    Forms),
        {clause, Args, Guards, Forms2}.


inline_form({call, {atom, FunName}, CallArgs},
            {Forms, Funs}) ->

    {ArgForms, _Funs} =
        lists:foldl(fun inline_form/2,
                    {[], Funs},
                    CallArgs),

    Arity = length(CallArgs),
    Clauses = maps:get({FunName, Arity}, Funs),
    {Clauses2, _Funs2} =
        lists:foldl(fun inline_clause/2,
                    {[], Funs},
                    Clauses),

    Case = {'case', {tuple, ArgForms}, Clauses2},
    {Forms ++ [Case], Funs};
inline_form(Form, {Forms, Funs}) ->
    {Forms ++ [Form], Funs}.

inline_clause({clause, Args, Guards, Body},
              {Forms, Funs}) ->
    Args2 = [{tuple, Args}],
    {Body2, _Funs} =
        lists:foldl(fun inline_form/2,
                    {[], Funs},
                    Body),
    Clause = {clause, Args2, Guards, Body2},
    {Forms ++ [Clause], Funs}.

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
