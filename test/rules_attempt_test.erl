-module(rules_attempt_test).

-behaviour(egre_rules).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, _Message}) ->
  NewProps = lists:keyreplace(should_change_to_true,
                              1,
                              Props,
                              {should_change_to_true, true}),
  {succeed, _Sub = false, NewProps};

attempt(_) ->
    undefined.

succeed({Props, _Msg = {_, sub}}) ->
    Props;
succeed({Props, _Msg = {_, nosub}}) ->
    throw(should_never_happen),
    Props.

fail({Props, _Message, _Reason}) ->
    throw(should_never_happen),
    Props.
