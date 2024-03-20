-module(rules_passthrough_test).

-behaviour(egre_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt(_) ->
    undefined.

succeed({Props, _Msg}) ->
    throw(should_never_happen),
    Props.

fail({Props, _Message, _Reason}) ->
    throw(should_never_happen),
    Props.
