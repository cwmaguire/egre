%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_rules).

-callback attempt({pid(), list(), tuple()}) -> any().
-callback succeed({pid(), tuple()}) -> list().
-callback fail({pid(), atom, tuple()}) -> list().
