%% Copyright (c) 2015, Chris Maguire <cwmaguire@gmail.com>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
-module(erlmud_handler_life_attack).

-behaviour(erlmud_handler).

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

is_dead_action(revive) ->
    true;
is_dead_action(_) ->
    false.

attempt({Owner, Props, Msg = {killed, _Attack, _Source, Owner}}) ->
    log([<<"attempt: ">>, Msg, <<", props: ">>, Props]),
    {succeed, _Subscribe = true, Props};
attempt({Owner, Props, _Msg = {die, Owner}}) ->
    {succeed, _Subscribe = true, Props};
attempt({Owner, Props, _Msg = {Action, _Attack, Owner, _Target, _}})
    when Action == calc_hit; Action == calc_damage ->
    case proplists:get_value(is_alive, Props, false) of
        false ->
            {{fail, target_is_dead}, _Subscribe = false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt({Owner, Props, _Msg = {Action, _Attack, _Attacker, Owner, _}})
    when Action == calc_hit; Action == calc_damage ->
    case proplists:get_value(is_alive, Props, false) of
        false ->
            {{fail, target_is_dead}, _Subscribe = false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt({Owner, Props, _Msg = {calc_next_attack_wait, _Attack, _Attacker, Owner, _, _}}) ->
    case proplists:get_value(is_alive, Props, false) of
        false ->
            {{fail, target_is_dead}, _Subscribe = false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt({Owner, Props, _Msg = {calc_next_attack_wait, _Attack, Owner, _Target, _, _}}) ->
    case proplists:get_value(is_alive, Props, false) of
        false ->
            {{fail, target_is_dead}, _Subscribe = false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt({Owner, Props, _Msg = {attack, _Attack, _Attacker, Owner}}) ->
    case proplists:get_value(is_alive, Props, false) of
        false ->
            %log("~p cannot attack ~p when ~p is dead~n", [Attacker, Owner, Owner]),
            {{fail, target_is_dead}, _Subscribe = false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt({Owner, Props, _Msg = {attack, _Attack, Owner, _Target}}) ->
    case proplists:get_value(is_alive, Props, false) of
        false ->
            {{fail, attacker_is_dead}, _Subscribe = false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt({Owner, Props, Msg}) when Owner == element(2, Msg) ->
    Action = element(1, Msg),
    IsAlive = proplists:get_value(is_alive, Props, false),
    IsDeadAction = is_dead_action(Action),
    case IsAlive orelse IsDeadAction of
        true ->
            {succeed, _Subscribe = false, Props};
        false ->
            AliveOrDead = case IsAlive of true -> "alive"; false -> "dead" end,
            FailMsg = iolist_to_binary(
                        io_lib:format("~p cannot ~p when ~p~n", [Owner, Action, AliveOrDead])),
            {{fail, FailMsg}, _Subscribe = false, Props}
    end;
attempt({Owner, Props, {calc_hit, Attack, Attacker, Owner, _}}) ->
    case proplists:get_value(is_alive, Props) of
        false ->
            {{resend, Attacker, {killed, Attack, Attacker, Owner}}, false, Props};
        _ ->
            {succeed, false, Props}
    end;
attempt(_) ->
    undefined.

succeed({Props, {killed, _Attack, _Source, Owner}}) ->
    %log("Character ~p killed by ~p, sending die: ~p~nprops: ~p~n",
        %[Owner, Source, Owner, Props]),
    erlmud_object:attempt(self(), {die, Owner}),
    Props;
succeed({Props, {die, Target}}) ->
    Owner = proplists:get_value(owner, Props),
    case Target of
        X when X == Owner ->
            CorpseCleanupMilis = application:get_env(erlmud, corpse_cleanup_milis, 10 * 60 * 1000),
            erlmud_object:attempt_after(CorpseCleanupMilis, self(), {cleanup, Owner}),
            lists:keystore(is_alive, 1, Props, {is_alive, false});
        _ ->
            Props
    end;
succeed({Props, _Msg}) ->
    %log("saw ~p succeed with props ~p~n", [Msg, Props]),
    throw(should_never_happen),
    Props.

fail({Props, _Message, _Reason}) ->
    %log("saw ~p fail with props ~p~n", [Message, Props]),
    throw(should_never_happen),
    Props.

log(Terms) ->
    erlmud_event_log:log(debug, [list_to_binary(atom_to_list(?MODULE)) | Terms]).