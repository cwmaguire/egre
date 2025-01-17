-module(level_2_decouple_case_disjunctions_in).

-export([attempt/1]).

attempt(Z) ->
    case Z of
        {A, B, {x}, x} when A == 1, B == 1; A == 2, B == 2 ->
            {A, B};
        {D, E} when D == 3; E == 4 ->
            ok
    end.
