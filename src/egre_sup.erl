%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Modules = [{super, {object_sup, egre_object_sup}},
               {worker, egre_index},
               {worker, egre_event_log},
               {worker, egre_event_log_json},
               {worker, egre_event_log_postgres},
               {worker, egre_postgres}],
    {ok, {{one_for_one, 1, 5}, procs(Modules)}}.

procs(Modules) ->
    lists:map(fun proc/1, Modules).

proc({super, {Id, Mod}}) ->
    {Id, {Mod, start_link, []}, permanent, brutal_kill, supervisor, [Mod]};
proc({worker, Mod}) ->
    {Mod, {Mod, start_link, []}, permanent, brutal_kill, worker, [Mod]}.
