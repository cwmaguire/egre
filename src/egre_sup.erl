%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Procs = [{object_sup,
              {egre_object_sup, start_link, []},
              permanent,
              brutal_kill,
              supervisor,
              [egre_object_sup]},
             {egre_index,
              {egre_index, start_link, []},
              permanent,
              brutal_kill,
              worker,
              [egre_index]},
             {egre_event_log,
              {egre_event_log, start_link, []},
              permanent,
              brutal_kill,
              worker,
              [egre_event_log]}],
    {ok, {{one_for_one, 1, 5}, Procs}}.
