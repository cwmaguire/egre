-module(rules_broadcast_test).

-behaviour(egre_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, {succeed, sub}}) ->
    %ct:pal("~p has props:~n~p", [self(), Props]),
    {{broadcast, {succeed, sub}}, _Sub = true, Props}.

succeed({Props, {succeed, sub}}) ->
    [{sub, true} | Props];
succeed({Props, _Msg}) ->
    throw(should_never_happen),
    Props.

fail({Props, _Message, _Reason}) ->
    throw(should_never_happen),
    Props.
