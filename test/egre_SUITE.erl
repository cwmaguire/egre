%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_SUITE).

-export([all/0]).
-export([init_per_suite/1]).
-export([end_per_suite/1]).
-export([init_per_testcase/2]).
-export([end_per_testcase/2]).

-export([start_object/1]).
-export([attempt_sub/1]).
-export([attempt_nosub/1]).
-export([attempt_after/1]).
-export([succeed_sub/1]).
-export([succeed_nosub/1]).
-export([fail_sub/1]).
-export([fail_nosub/1]).
-export([second_order_sub/1]).
-export([set/1]).
-export([populate/1]).
-export([broadcast/1]).
-export([resend/1]).
-export([stop/1]).
-export([revive_process/1]).

-include("egre.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(WAIT100, receive after 100 -> ok end).

all() ->
    [start_object,
     attempt_sub,
     attempt_nosub,
     attempt_after,
     succeed_sub,
     succeed_nosub,
     fail_sub,
     fail_nosub,
     second_order_sub,
     set,
     populate,
     broadcast,
     resend,
     stop,
     revive_process].

init_per_suite(Config) ->
    %egre_dbg:add(egre_object, handle_cast_),
    %egre_dbg:add(egre_event_log, add_index_details),

    %dbg:tracer(),
    %dbg:tpl(egre_event_log, '_', '_', [{'_', [], [{exception_trace}]}]),

    {ok, _Started} = application:ensure_all_started(egre),
    {atomic, ok} = mnesia:clear_table(object),
    TestObject = spawn_link(fun mock_object/0),
    egre_index:put([{pid, TestObject}, {id, test_object}]),
    [{test_object, TestObject} | Config].

end_per_suite(_Config) ->
    ct:pal("~p stopping egre~n", [?MODULE]),
    receive after 1000 -> ok end,
    application:stop(egre).

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    case assert_ct_test_process_mailbox_empty() of
        fail ->
            {fail, "CT test processes should not be getting messages"};
        _ ->
            return_ignored
    end.

all_vals(Key, Obj) ->
    Props = case get_props(Obj) of
                undefined ->
                    [];
                Props_ ->
                    Props_
            end,
    proplists:get_all_values(Key, Props).

val(Key, Obj) ->
    case all_vals(Key, Obj) of
        [First | _] ->
            First;
        _ ->
            []
    end.

all(Key, Obj) ->
    proplists:get_all_values(Key, get_props(Obj)).

has(Val, Obj) ->
    false /= lists:keyfind(Val, 2, get_props(Obj)).

get_props(undefined) ->
    [];
get_props(Obj) when is_atom(Obj) ->
    Pid = get_pid(Obj),
    get_props(Pid);
get_props(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of
        true ->
            {_RecordName, Props} = sys:get_state(Pid),
            Props;
        false ->
            undefined
    end.

%%
%% Tests
%%

start_object(_Config) ->
    Props = [{prop, "prop"}],
    [{id, Pid}] = start([{id, Props}]),
    ?WAIT100,
    ExpectedProps = Props ++ [{id, id}, {pid, Pid}],
    StoredProps = egre_object:props(Pid),
    ?assertEqual(StoredProps, ExpectedProps).

attempt_sub(_Config) ->
    Props = [{should_change_to_true, false},
             {rules, [rules_attempt_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {any_message_will_do, sub}),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(should_change_to_true, StoredProps),
    ?assertEqual(Expected, Result).

attempt_nosub(_Config) ->
    Props = [{should_change_to_true, false},
             {rules, [rules_attempt_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {any_message_will_do, nosub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(should_change_to_true, StoredProps),
    ?assertEqual(Expected, Result).

attempt_after(_Config) ->
    Props = [{should_change_to_true, false},
             {rules, [rules_attempt_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(700, Pid, {any_message_will_do, nosub}, _ShouldSub = false),

    receive after 200 -> ok end,
    StoredPropsBefore = egre_object:props(Pid),
    ExpectedBefore = false,
    ResultBefore = proplists:get_value(should_change_to_true, StoredPropsBefore),
    ?assertEqual(ExpectedBefore, ResultBefore),

    receive after 1000 -> ok end,
    StoredPropsAfter = egre_object:props(Pid),
    ExpectedAfter = true,
    ResultAfter = proplists:get_value(should_change_to_true, StoredPropsAfter),
    ?assertEqual(ExpectedAfter, ResultAfter).


succeed_sub(_Config) ->
    Props = [{rules, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {succeed, sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

succeed_nosub(_Config) ->
    Props = [{rules, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {succeed, no_sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = undefined,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

fail_sub(_Config) ->
    Props = [{rules, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {fail, sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

fail_nosub(_Config) ->
    Props = [{rules, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {fail, no_sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = undefined,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

set(_Config) ->
    Props = [{should_change_to_true, false}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:set(Pid, {should_change_to_true, true}),
    ?WAIT100,
    StoredProps1 = egre_object:props(Pid),
    Expected1 = true,
    Result1 = proplists:get_value(should_change_to_true, StoredProps1),
    ?assertEqual(Expected1, Result1),
    egre_object:set(Pid, {new_key, new_value}),
    ?WAIT100,
    StoredProps2 = egre_object:props(Pid),
    Expected2 = new_value,
    Result2 = proplists:get_value(new_key, StoredProps2),
    ?assertEqual(Expected2, Result2).

populate(_Config) ->
    Id1 = random_atom(),
    Id2 = random_atom(),

    Props1 = [{a, b}, {object2, Id2}],
    [{Id1_, Pid1}] = start([{Id1, Props1}]),
    ?assertEqual(Id1, Id1_),

    Props2 = [{c, d}, {object1, Id1}],
    [{Id2_, Pid2}] = start([{Id2, Props2}]),
    ?assertEqual(Id2, Id2_),
    ?WAIT100,

    IdPids = [{Id1, Pid1}, {Id2, Pid2}],

    egre_object:populate(Pid1, IdPids),
    egre_object:populate(Pid2, IdPids),

    StoredProps1 = egre_object:props(Pid1),
    Expected1 = Pid2,
    Result1 = proplists:get_value(object2, StoredProps1),
    ?assertEqual(Expected1, Result1),

    StoredProps2 = egre_object:props(Pid2),
    Expected2 = Pid1,
    Result2 = proplists:get_value(object1, StoredProps2),
    ?assertEqual(Expected2, Result2).

second_order_sub(_Config) ->
    Id1 = random_atom(),
    Id2 = random_atom(),

    Props1 = [{should_stay_false, false},
              {rules, [rules_passthrough_test]},
              {object2, Id2}],
    [{_Id1, Pid1}] = start([{Id1, Props1}]),

    Props2 = [{rules, [rules_sub_test]}],
    [{_Id2, Pid2}] = start([{Id2, Props2}]),

    IdPids = [{Id1, Pid1}, {Id2, Pid2}],

    egre_object:populate(Pid1, IdPids),
    %egre_object:populate(Pid2, IdPids),

    ShouldSub = false,

    ?WAIT100,
    egre_object:attempt_after(0, Pid1, {succeed, sub}, ShouldSub),
    ?WAIT100,
    StoredProps1 = egre_object:props(Pid2),
    Expected1 = true,
    Result1 = proplists:get_value(sub, StoredProps1),
    ?assertEqual(Expected1, Result1),

    ?WAIT100,
    egre_object:set(Pid2, {sub, undefined}),
    ?WAIT100,
    egre_object:attempt_after(0, Pid1, {succeed, no_sub}, ShouldSub),
    ?WAIT100,
    StoredProps2 = egre_object:props(Pid2),
    Expected2 = undefined,
    Result2 = proplists:get_value(sub, StoredProps2),
    ?assertEqual(Expected2, Result2),

    ?WAIT100,
    egre_object:set(Pid2, {sub, undefined}),
    ?WAIT100,
    egre_object:attempt_after(0, Pid1, {fail, sub}, ShouldSub),
    ?WAIT100,
    StoredProps3 = egre_object:props(Pid2),
    Expected3 = true,
    Result3 = proplists:get_value(sub, StoredProps3),
    ?assertEqual(Expected3, Result3),

    ?WAIT100,
    egre_object:set(Pid2, {sub, undefined}),
    ?WAIT100,
    egre_object:attempt_after(0, Pid1, {fail, no_sub}, ShouldSub),
    ?WAIT100,
    StoredProps4 = egre_object:props(Pid2),
    Expected4 = undefined,
    Result4 = proplists:get_value(sub, StoredProps4),
    ?assertEqual(Expected4, Result4).

broadcast(_Config) ->
    ValidObject1Id = random_atom(),
    ValidObject2Id = random_atom(),
    InvalidObjectId = random_atom(),

    BroadcastFilterFun =
        fun({yes_broadcast_pid, Pid}) when is_pid(Pid) ->
                {true, Pid};
           (_Prop) ->
                false
        end,

    V1Props = [{rules, [rules_broadcast_test]},
               {name, v1},
               {broadcast_pid_filter, BroadcastFilterFun},
               {yes_broadcast_pid, ValidObject2Id},
               {no_broadcast_pid, InvalidObjectId}],

    [{V1Id, V1Pid}] = start([{ValidObject1Id, V1Props}]),

    V2Props = [{rules, [rules_sub_test]},
               {name, v2}],

    [{V2Id, V2Pid}] = start([{ValidObject2Id, V2Props}]),

    InvalidProps = [{rules, [rules_sub_test]}],
    [{InvId, InvPid}] = start([{InvalidObjectId, InvalidProps}]),

    IdPids = [{V1Id, V1Pid},
              {V2Id, V2Pid},
              {InvId, InvPid}],

    [egre_object:populate(Pid, IdPids) || {_Id, Pid} <- IdPids],

    ?WAIT100,
    egre_object:attempt_after(0, V1Pid, {succeed, sub}, _Sub = false),
    receive after 200 -> ok end,

    assertProp(V1Pid, sub, undefined, ?LINE),
    assertProp(V2Pid, sub, true, ?LINE),
    assertProp(InvPid, sub, undefined, ?LINE).

resend(_Config) ->
    Id = random_atom(),
    Props = [{rules, [rules_resend_test]}],
    [{_Id, Pid}] = start([{Id, Props}]),

    ?WAIT100,
    egre_object:attempt_after(0, Pid, {resend}, _Sub = false),
    ?WAIT100,
    assertProp(Pid, resent, true, ?LINE),
    assertProp(Pid, received, true, ?LINE),
    assertProp(Pid, sub, true, ?LINE).

stop(_Config) ->
    Id = random_atom(),

    Props = [{rules, [rules_stop_test]},
               {name, v1}],

    [{_Id, Pid}] = start([{Id, Props}]),

    ?WAIT100,
    egre_object:attempt_after(0, Pid, {stop}, _Sub = false),
    receive after 200 -> ok end,

    ?assertNot(erlang:is_process_alive(Pid)).


revive_process(_Config) ->
    Object = {obj_name,
              [{prop1, <<"value1">>}]},
    start([Object]),

    PlayerV1 = get_pid(player),
    ct:pal("~p: PlayerV1~n\t~p~n", [?MODULE, PlayerV1]),

    Room = val(owner, player),
    true = is_pid(Room),
    HP = val(hitpoints, player),
    true = is_pid(HP),
    Life = val(life, player),
    true = is_pid(Life),
    Dex = val(attribute, player),
    true = is_pid(Dex),
    Stamina = val(resource, player),
    true = is_pid(Stamina),
    Hand = val(body_part, player),
    true = is_pid(Hand),

    ?assertMatch(PlayerV1, val(owner, p_hp)),
    ?assertMatch(PlayerV1, val(owner, p_life)),
    ?assertMatch(PlayerV1, val(owner, p_hand_right)),
    ?assertMatch(PlayerV1, val(character, p_fist_right)),
    ?assertMatch(PlayerV1, val(owner, dexterity0)),
    ?assertMatch(PlayerV1, val(owner, p_stamina)),

    exit(PlayerV1, kill),
    ?WAIT100,

    PlayerV2 = get_pid(player),
    false = PlayerV1 == PlayerV2,

    ?assertMatch(Room, val(owner, player)),
    ?assert(is_pid(Room)),
    ?assertMatch(HP, val(hitpoints, player)),
    ?assert(is_pid(HP)),
    ?assertMatch(Life, val(life, player)),
    ?assert(is_pid(Life)),
    ?assertMatch(Dex, val(attribute, player)),
    ?assert(is_pid(Dex)),
    ?assertMatch(Stamina, val(resource, player)),
    ?assert(is_pid(Stamina)),
    ?assertMatch(Hand, val(body_part, player)),
    ?assert(is_pid(Hand)),

    ?assertMatch(PlayerV2, val(owner, p_hp)),
    ?assertMatch(PlayerV2, val(owner, p_life)),
    ?assertMatch(PlayerV2, val(owner, p_hand_right)),
    ?assertMatch(PlayerV2, val(character, p_fist_right)),
    ?assertMatch(PlayerV2, val(owner, dexterity0)),
    ?assertMatch(PlayerV2, val(owner, p_stamina)).

%%
%% END TESTS
%%

start(Objects) ->
    IdPids = egre:create_graph(Objects),
    timer:sleep(100),
    IdPids.

assert_ct_test_process_mailbox_empty() ->
    receive
        X ->
            ct:pal("~p:~p: CT test process got message: ~p~n", [?MODULE, ?FUNCTION_NAME, X]),
            fail
        after 0 ->
            ok
    end.

assertProp(Pid, Key, Value, Line) ->
    Props = egre_object:props(Pid),
    %ct:pal("~p:~p: Pid ~p: Expecting {~p, ~p}, got Props~n\t~p~n",
    %       [?MODULE, ?FUNCTION_NAME, Pid, Key, Value, Props]),
    Expected = Value,
    Actual = proplists:get_value(Key, Props),
    ?assertEqual(Expected, Actual, {expected_prop_with_key, Key, and_value, Value, on_line, Line}).

% Add to commit comment
% This is from f8e3ccfadaef667e39934d38e8f2e6e49a978a78
% 2015-08-01
%
% The test suite now creates a mock erlmud_object to receive gen_server
% calls to get props. All test attempts go through this object. When the
% receiver of the attempt logs the attempt erlmud_event_log tries to get
% the props from the object sending the attempt. The mocked out object
% will simply return an empty list.

mock_object() ->
    receive
        X ->
            case X of
                {'$gen_call', _Msg = {From, MonitorRef}, props} ->
                    From ! {MonitorRef, _MockProps = []};
                {attempt, Target, Message} ->
                    egre_object:attempt(Target, Message, false);
                stop ->
                    exit(normal);
                _Other ->
                    ok
            end
    end,
    mock_object().

get_pid(Id) ->
    #object{pid = Pid} = egre_index:get(Id),
    Pid.

random_atom() ->
    list_to_atom([rand:uniform(94) + 32 || _ <- lists:seq(1,10)]).
