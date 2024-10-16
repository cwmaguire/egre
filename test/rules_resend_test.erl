-module(rules_resend_test).

-behaviour(egre_rules).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, {resend}}) ->
    {{resend, self(), {succeed, sub}}, _Sub = ignored, [{resent, true} | Props]};
attempt({_Parents, Props, {succeed, sub}}) ->
    {succeed, _Sub = true, [{received, true} | Props]}.

succeed({Props, {succeed, sub}}) ->
    case lists:keyfind(sub, 1, Props) of
        false ->
            [{sub, true} | Props];
        {sub, Value} ->
            ct:fail("Object ~p already had {sub, ~p}~nProps: ~p", [self(), Value, Props])
    end;
succeed({Props, _Msg}) ->
    throw(should_never_happen),
    Props.

fail({Props, _Message, _Reason}) ->
    throw(should_never_happen),
    Props.
