-module(rules_test).

-behaviour(egre_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({_Parents, Props, _Message}) ->
  NewProps = lists:keyreplace(should_change_to_true,
                              1,
                              Props,
                              {should_change_to_true, true}),

  ct:pal("~p:~p: NewProps~n\t~p~n", [?MODULE, ?FUNCTION_NAME, NewProps]),
  {succeed, _Sub = false, NewProps};

attempt(_) ->
    undefined.

succeed(_) ->
    ok.

fail(_) ->
    ok.
