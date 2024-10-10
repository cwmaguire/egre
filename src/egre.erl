%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre).

-export([create_graph/1]).

create_graph(Objects) ->
    IdPids = [{Id, start_obj(Id, Props)} || {Id, Props} <- Objects],
    [egre_object:populate(Pid, IdPids) || {_, Pid} <- IdPids],
    IdPids.

start_obj(Id, Props) ->
    {ok, Pid} = supervisor:start_child(egre_object_sup, [Id, Props]),
    Pid.
