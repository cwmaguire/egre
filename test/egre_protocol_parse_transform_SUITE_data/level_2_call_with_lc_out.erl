-module(level_2_call_with_lc_out).

-export([succeed/1]).

succeed(_) ->
    case {} of
        {} ->
            [case {} of
                 {} ->
                     [egre:attempt(process, {foo, bar}) || _ <- []]
             end || _ <- []]
    end.
