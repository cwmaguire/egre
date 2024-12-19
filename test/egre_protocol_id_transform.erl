-module(egre_protocol_id_transform).

-export([parse_transform/2]).

parse_transform(Forms = [FilenameAttribute | _], _Options) ->
    Filename = filename(FilenameAttribute),
    ct:pal("~p:~p: Filename~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Filename]),

    ApiFuns = lists:filter(fun is_api_fun/1, Forms),

    Path = path(),
    {ok, IO} = file:open(Path ++ Filename, [write]),
    FormsIolist = io_lib:format("~p", [ApiFuns]),
    file:write(IO, FormsIolist),
    file:close(IO),
    Forms.

filename({attribute, _, file, {Filename, _}}) ->
    filename:rootname(filename:basename(Filename)).

path() ->
    case os:getenv("EGRE_PARSE_TRANSFORM_OUT_DIR") of
        false ->
            "/home/c/dev/egre/";
        Path ->
            Path
    end.

is_api_fun({function, _, attempt, _, _}) ->
    true;
is_api_fun({function, _, succeed, _, _}) ->
    true;
is_api_fun(_) ->
    false.
