%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_event_log_json).

-behaviour(gen_server).

-export([start_link/0]).
-export([log/2]).
-export([register_logger/1]).

%% gen_server

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {log_file :: file:io_device(),
                loggers = [],
                serialize_fun :: fun()}).

%% API

log(_Props, Terms) ->
    case whereis(?MODULE) of
        undefined ->
            %io:format(user,
                      %"egre_event_log process not found~n"
                      %"Pid: ~p, Level: ~p, Terms: ~p~n",
                      %[Pid, Level, Terms]);
            ok;
        _ ->
            gen_server:cast(?MODULE, {log, Terms})
    end.

register_logger(Logger) when is_function(Logger) ->
    gen_server:cast(?MODULE, {register, Logger}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server

init([]) ->
    process_flag(priority, max),
    LogPath = get_log_path(),
    {ok, LogFile} = file:open(LogPath ++ "/egre.log", [append]),
    {ok, {M, F, 2}} = application:get_env(egre, serialize_fun),
    {ok, #state{log_file = LogFile,
                serialize_fun = fun M:F/2}}.

handle_call(_Msg, _From, State) ->
    {reply, ignored, State}.

handle_cast({log, Proplist}, State = #state{loggers = Loggers}) when is_list(Proplist) ->
    FlattenedKeys = [{flatten_key(K), V} || {K, V} <- Proplist],
    JSON =
        try
            jsx:encode(FlattenedKeys)
        catch
            Class:Error ->
                io:format(user,
                          "~p: ~p caught error: ~p:~p~n~p~n",
                          [self(), ?MODULE, Class, Error, FlattenedKeys]),
                {error, Error}
        end,
    ok = file:write(State#state.log_file, <<JSON/binary, "\n">>),
    [call_logger(Logger, _Level = undefined, JSON) || Logger <- Loggers],

    {noreply, State};
handle_cast({register, Logger}, State = #state{loggers = Loggers}) ->
    {noreply, State#state{loggers = [Logger | Loggers]}};
handle_cast(Msg, State) ->
    io:format(user, "Unrecognized cast: ~p~n", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    io:format(user, "~p: ~p:handle_info(~p, State)~n", [self(), ?MODULE, Info]),
    {noreply, State}.

terminate(Reason, State) ->
    io:format(user, "Terminating egre_event_log: ~p~n~p~n", [Reason, State]).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% util

get_log_path() ->
    case os:getenv("EGRE_LOG_PATH") of
        false ->
            {ok, CWD} = file:get_cwd(),
            CWD;
        Path ->
            Path
    end.

call_logger(Logger, Level, JSON) ->
    try
        Logger(Level, JSON)
    catch
        Class:Error ->
            io:format(user,
                      "~p: ~p caught error calling Logger function:~n\t~p:~p~n",
                      [self(), ?MODULE, Class, Error])
    end.

flatten_key([A1, <<" ">>, A2]) when is_atom(A1), is_atom(A2) ->
    B1 = atom_to_binary(A1, utf8),
    B2 = atom_to_binary(A2, utf8),
    <<B1/binary, "_", B2/binary>>;
flatten_key(Other) ->
    Other.
