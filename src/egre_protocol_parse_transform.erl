-module(egre_protocol_ast_translate).

-export([parse_transform/2]).

parse_transform(Forms, _Options) ->
    InlinedApiFunctions = translate_ast(Forms),
    egre_parse_transform_event_chains:extract(InlinedApiFunctions),
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
    InlinedFuns,
    Path = path(),
    {ok, IO} = file:open(Path ++ FileRoot, [write]),
    FormsIolist = io_lib:format("~p", [InlinedFuns]),
    file:write(IO, FormsIolist),
    file:close(IO),
    maps:to_list(InlinedFuns).

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

inline_api_clause(Module, {clause, Args, Guards, Forms}, Funs) ->

    {Module, Forms2, _Funs} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs},
                    Forms),
        {clause, Args, Guards, Forms2}.


inline_form({call, {atom, FunName}, CallArgs},
            {Module, Forms, Funs}) ->

    {Module, ArgForms, _Funs} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs},
                    CallArgs),

    Arity = length(CallArgs),
    Clauses = maps:get({Module, FunName, Arity}, Funs),
    {Module, Clauses2, _Funs2} =
        lists:foldl(fun inline_clause/2,
                    {Module, [], Funs},
                    Clauses),

    Case = {'case', {tuple, ArgForms}, Clauses2},
    {Module, Forms ++ [Case], Funs};
inline_form(Form, {Module, Forms, Funs}) ->
    {Module, Forms ++ [Form], Funs}.

inline_clause({clause, Args, Guards, Body},
              {Module, Forms, Funs}) ->
    Args2 = [{tuple, Args}],
    {Module, Body2, _Funs} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs},
                    Body),
    Clause = {clause, Args2, Guards, Body2},
    {Module, Forms ++ [Clause], Funs}.

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
