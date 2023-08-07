%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_handler).

-callback attempt({pid(), list(), tuple()}) -> any().
-callback succeed({pid(), tuple()}) -> list().
-callback fail({pid(), atom, tuple()}) -> list().
