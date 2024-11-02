%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_event_log_postgres).

-behaviour(gen_server).

-export([start_link/0]).
-export([log/2]).

%% gen_server

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {serialize_fun :: mfa()}).

%% API

log(Props, _Terms) ->
    gen_server:cast(?MODULE, {log, Props}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server

init([]) ->
    {ok, {M, F, A}} = application:get_env(egre, serialize_fun),
    {ok, #state{serialize_fun = fun M:F/A}}.

handle_call(_Msg, _From, State) ->
    {reply, ignored, State}.

handle_cast({log, Props},
            State = #state{serialize_fun = SerializeFun})
  when is_list(Props) ->
    log_to_db(Props, SerializeFun),
    {noreply, State};
handle_cast(Msg, State) ->
    io:format(user, "Unrecognized cast: ~p~n", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    io:format(user, "~p:handle_info(~p, State)~n", [?MODULE, Info]),
    {noreply, State}.

terminate(Reason, State) ->
    io:format(user, "Terminating egre_event_log: ~p~n~p~n", [Reason, State]).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% util

log_to_db(Props, SerializeFun) ->
    PID = proplists:get_value(pid, Props, no_pid),
    Mod = proplists:get_value(rules_module, Props, no_rules_module),
    Message = proplists:get_value(message, Props, no_message),

    Values = [egre_serialize:serialize(V, SerializeFun) || V <- [PID, Mod, Message]],
    BinValues = lists:map(fun to_binary/1, Values),
    egre_postgres:insert(BinValues).

to_binary(Values) ->
    iolist_to_binary(to_binary_(Values)).

to_binary_(Values) when is_list(Values) ->
    lists:map(fun to_binary/1, Values);
to_binary_(Bin) when is_binary(Bin) ->
    Bin;
to_binary_(Atom) when is_atom(Atom) ->
    atom_to_binary(Atom, utf8);
to_binary_(Int) when is_integer(Int) ->
    integer_to_binary(Int);
to_binary_(Float) when is_float(Float) ->
    float_to_binary(Float);
to_binary_(Map) when is_map(Map) ->
    iolist_to_binary(io_lib:format("~p", [Map])).
