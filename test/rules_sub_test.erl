-module(rules_sub_test).

-behaviour(egre_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, {succeed, sub}}) ->
  {succeed, _Sub = true, Props};

attempt({_Parents, Props, {succeed, no_sub}}) ->
  {succeed, _Sub = false, Props};

attempt({_Parents, Props, {fail, sub}}) ->
  {{fail, fail_reason}, _Sub = true, Props};

attempt({_Parents, Props, {fail, no_sub}}) ->
  {{fail, fail_reason}, _Sub = false, Props};

attempt(_) ->
    undefined.

%% crash if get success on anything but {succeed, sub}
succeed({Props, {succeed, sub}}) ->
    [{sub, true} | Props].

%% crash if get failed on anything but {failed, sub}
fail({Props, fail_reason, {fail, sub}}) ->
    [{sub, true} | Props].

