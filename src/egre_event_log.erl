%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_event_log).

-behaviour(gen_server).

-include("egre.hrl").

-export([start_link/0]).
-export([log/2]).
-export([log/3]).
-export([flatten/1]).

%% gen_server

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {serialize_fun :: mfa()}).

%% API

log(Level, Terms) when is_atom(Level) ->
    Self = self(),
    log(Self, Level, Terms).

log(Pid, Level, Terms) when is_atom(Level) ->
    gen_server:cast(?MODULE, {log, Pid, Level, Terms}).

flatten(Props) ->
    Flattened = flatten(Props, []),
    lists:ukeysort(1, Flattened).

flatten([], List) ->
    List;
flatten([{K, [{K2, V} | L]} | Rest], Out) ->
    flatten([{K, L} | Rest], [{K2, V} | Out]);
flatten([T | Rest], Out) when is_tuple(T) ->
    flatten(Rest, [T | Out]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server

init([]) ->
    process_flag(priority, max),
    {ok, {M, F, A}} = application:get_env(egre, serialize_fun),
    io:format("Starting logger (~p)~n", [self()]),
    {ok, #state{serialize_fun = fun M:F/A}}.

handle_call(Request, From, State) ->
    io:format(user, "egre_event_log:handle_call(~p, ~p, ~p)~n",
              [Request, From, State]),
    {reply, ignored, State}.

handle_cast({log, Pid, Level, Props},
            State = #state{serialize_fun = CustomSerializeFun})
  when is_list(Props) ->
    Props2 = [{process, Pid}, {level, Level} | Props],
    NamedProps = add_index_details(Props2),
    S = fun(Val, Fun) ->
                egre_serialize:serialize(Val, Fun)
        end,
    BinProps = [{S(K, CustomSerializeFun), S(V, CustomSerializeFun)}
                || {K, V} <- NamedProps],

    egre_event_log_json:log(NamedProps, BinProps),
    egre_event_log_postgres:log(NamedProps, BinProps),
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

add_index_details(Props) ->
    lists:foldl(fun add_index_details/2, [], Props).

%% TODO Rethink this: for every object I log, I'm calling index:get(Pid)
%% for every property that is a pid. I think I end up building a table of
%% all the PID IDs anyway, so I don't think I need this. That is, the web
%% page or the database will have a record of the ID for every pid. Any
%% top level PID that gets logged stores the ID of that PID for every other
%% log message.
add_index_details({_Key = {Atom1, Atom2}, Pid}, NamedProps)
  when is_pid(Pid),
       is_atom(Atom1),
       is_atom(Atom2) ->
    Str1 = atom_to_list(Atom1),
    Str2 = atom_to_list(Atom2),
    Key = list_to_atom(Str1 ++ "_" ++ Str2),
    add_index_details({Key, Pid}, NamedProps);
add_index_details({Key, Pid}, NamedProps) when is_pid(Pid) ->
    case egre_index:get(Pid) of
        undefined ->
            NamedProps;
        #object{id = Id, icon = Icon} ->
            IdKey = list_to_atom(atom_to_list(Key) ++ "_id"),
            IconKey = list_to_atom(atom_to_list(Key) ++ "_icon"),
            Props = [P || P = {_, V} <- [{IdKey, Id}, {IconKey, Icon}], V /= undefined],
            [{Key, Pid} | Props] ++ NamedProps
    end;
add_index_details(Prop, NamedProps) ->
    [Prop | NamedProps].

