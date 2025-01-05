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
    InlinedFuns,
    Path = path(),
    {ok, IO} = file:open(Path ++ "/" ++ FileRoot, [write]),
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

    {Module, Forms2, _Funs, _} =
        lists:foldl(fun inline_form/2,
                    {Module, [], Funs, []},
                    Forms),
        {clause, Args, Guards, Forms2}.

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

inline_form(LCForm = {lc, Body, Generators},
            {Module, Forms, Funs, InlinedFuns}) ->
    io:format(user, "LC Form = ~p~n", [LCForm]),
    {Module, [BodyForm], _, InlinedFuns2} =
        inline_form(Body, {Module, [], Funs, InlinedFuns}),

    {Module, GeneratorForms, _, InlinedFuns3} =
        lists:foldl(fun inline_lc_generator/2,
                    {Module, [], Funs, InlinedFuns2},
                    Generators),

    LC = {lc, BodyForm, GeneratorForms},
    {Module, Forms ++ [LC], Funs, InlinedFuns3};

inline_form(Form, {Module, Forms, Funs, InlinedFuns}) ->
    io:format(user, "Form = ~p~n", [Form]),
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
