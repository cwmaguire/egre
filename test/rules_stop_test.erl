-module(rules_stop_test).

-behaviour(egre_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, {stop}}) ->
    {succeed, _Sub = true, Props}.

succeed({Props, {stop}}) ->
    {stop, testing, _Props = [{stopped, true} | Props], _LogProps = []};
succeed({Props, _Msg}) ->
    throw(should_never_happen),
    Props.

fail({Props, _Message, _Reason}) ->
    throw(should_never_happen),
    Props.
