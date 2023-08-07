%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre).

-export([create/2]).

create(Type, Props) ->
    egre_object:start_link('TODO_add_object_id', Type, Type:create(Props)).
