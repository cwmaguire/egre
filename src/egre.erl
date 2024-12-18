%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre).

-include("egre.hrl").

-export([set/2]).
-export([create_graph/1]).
-export([get_object/1]).
-export([get_object_pid/1]).
-export([start_object/1]).
-export([attempt/2]).
-export([attempt/3]).
-export([attempt/4]).
-export([attempt_after/3]).
-export([register_logger/2]).
-export([wait_db_ready/0]).
-export([wait_db_done/1]).

create_graph(Objects) ->
    IdPids = [{Id, start_object(Id, Props)} || {Id, Props} <- Objects],
    [egre_object:populate(Pid, IdPids) || {_, Pid} <- IdPids],
    IdPids.

-spec start_object(proplist()) -> pid().
start_object(Properties) ->
    start_object(_Id = undefined, Properties).

-spec start_object(atom(), proplist()) -> pid().
start_object(Id, Props) ->
    {ok, Pid} = supervisor:start_child(egre_object_sup, [Id, Props]),
    Pid.

-spec get_object(pid()) -> #object{}.
get_object(Pid) ->
    egre_index:get(Pid).

-spec get_object_pid(atom()) -> pid().
get_object_pid(Id) ->
    egre_index:get_pid(Id).

set(Pid, Property) ->
    egre_object:set(Pid, Property).

-spec attempt(pid(), tuple()) -> any().
attempt(ObjectPid, Event) ->
    attempt(ObjectPid, Event, true).

-spec attempt(pid(), tuple(), boolean()) -> any().
attempt(ObjectPid, Event, ShouldSubscribe) ->
    attempt(ObjectPid, Event, [], ShouldSubscribe).

-spec attempt(pid(), tuple(), map(), boolean()) -> any().
attempt(ObjectPid, Event, Context, ShouldSubscribe) ->
    egre_object:attempt(ObjectPid, Event, Context, ShouldSubscribe).

attempt_after(Millis, ObjectPid, Event) ->
    egre_object:attempt_after(Millis, ObjectPid, Event).

register_logger(json, Fun) ->
    egre_event_log_json:register_logger(Fun).

wait_db_ready() ->
    io:format(user, "Caller ~p waiting for DB to be ready~n", [self()]),
    egre_postgres:wait_ready(),
    io:format(user, "Caller ~p: DB ready~n", [self()]).

wait_db_done(Millis) ->
    Time1 = erlang:localtime(),
    io:format(user, "~p Caller ~p waiting for DB to be finished~n", [Time1, self()]),
    Result = egre_postgres:wait_done(Millis),
    Time2 = erlang:localtime(),
    io:format(user, "~p Caller ~p: DB finished~n", [Time2, self()]),
    Result.
