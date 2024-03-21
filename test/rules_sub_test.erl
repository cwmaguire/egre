-module(rules_sub_test).

-behaviour(egre_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, {succeed, sub}}) ->
  %ct:pal("~p got {succeed, sub} with Props:~n~p", [self(), Props]),
  {succeed, _Sub = true, Props};

attempt({_Parents, Props, {succeed, no_sub}}) ->
  %ct:pal("~p got {succeed, no_sub} with Props:~n~p", [self(), Props]),
  {succeed, _Sub = false, Props};

attempt({_Parents, Props, {fail, sub}}) ->
  %ct:pal("~p got {fail, sub} with Props:~n~p", [self(), Props]),
  {{fail, fail_reason}, _Sub = true, Props};

attempt({_Parents, Props, {fail, no_sub}}) ->
  %ct:pal("~p got {fail, no_sub} with Props:~n~p", [self(), Props]),
  {{fail, fail_reason}, _Sub = false, Props};

attempt({_Parents, _Props, _X}) ->
    %ct:pal("~p got ~p with Props:~n~p", [self(), X, Props]),
    undefined.

%% crash if get success on anything but {succeed, sub}
succeed({Props, {succeed, sub}}) ->
    case lists:keyfind(sub, 1, Props) of
        false ->
            [{sub, true} | Props];
        {sub, Value} ->
            ct:fail("Object ~p already had {sub, ~p}~nProps: ~p", [self(), Value, Props])
    end.

%% crash if get failed on anything but {failed, sub}
fail({Props, fail_reason, {fail, sub}}) ->
    [{sub, true} | Props].

