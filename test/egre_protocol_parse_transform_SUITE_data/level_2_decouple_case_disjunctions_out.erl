-module(level_2_decouple_case_disjunctions_out).

-export([attempt/1]).

attempt(Z) ->
    case Z of
        {A, B, {x}, x} when A == 1, B == 1 ->
            ok
    end;
attempt(Z) ->
    case Z of
        {A, B, {x}, x} when A == 2, B == 2 ->
            ok
    end;
attempt(Z) ->
    case Z of
        {D, E} when D == 3 ->
            ok
    end;
attempt(Z) ->
    case Z of
        {D, E} when E == 4 ->
            ok
    end.
