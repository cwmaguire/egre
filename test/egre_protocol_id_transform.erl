-module(egre_protocol_id_transform).

-export([parse_transform/2]).

parse_transform([FilenameAttribute | Forms], _Options) ->
    Filename = filename(FilenameAttribute),

    Forms2 = [strip_lines(F) || F <- Forms],
    ApiFuns = lists:filter(fun is_api_fun/1, Forms2),
    Map = maps:from_list([fun2kv(F) || F <- ApiFuns]),

    Path = path(),
    {ok, IO} = file:open(Path ++ Filename, [write]),
    FormsIolist = io_lib:format("~p", [Map]),
    file:write(IO, FormsIolist),
    file:close(IO),
    Forms.

filename({attribute, _, file, {Filename, _}}) ->
    filename:rootname(filename:basename(Filename)).

path() ->
    case os:getenv("EGRE_PARSE_TRANSFORM_OUT_DIR") of
        false ->
            {ok, CWD} = file:get_cwd(),
            CWD;
        Path ->
            Path
    end.

is_api_fun({function, attempt, _, _}) ->
    true;
is_api_fun({function, succeed, _, _}) ->
    true;
is_api_fun(_) ->
    false.

fun2kv({function, Name, Arity, Clauses}) ->
    {{Name, Arity}, Clauses}.

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
