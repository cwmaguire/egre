%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_SUITE).
-compile(export_all).

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
     fail_nosub].

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
             {handlers, [rules_attempt_test]}],
    [{Id, Pid}] = start([{undefined, Props}]),
    ct:pal("~p:~p: Started ~p with pid~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Id, Pid]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {any_message_will_do, sub}),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(should_change_to_true, StoredProps),
    ?assertEqual(Expected, Result).

attempt_nosub(_Config) ->
    Props = [{should_change_to_true, false},
             {handlers, [rules_attempt_test]}],
    [{Id, Pid}] = start([{undefined, Props}]),
    ct:pal("~p:~p: Started ~p with pid~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Id, Pid]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {any_message_will_do, nosub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(should_change_to_true, StoredProps),
    ?assertEqual(Expected, Result).

attempt_after(_Config) ->
    Props = [{should_change_to_true, false},
             {handlers, [rules_attempt_test]}],
    [{Id, Pid}] = start([{undefined, Props}]),
    ct:pal("~p:~p: Started ~p with pid~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Id, Pid]),
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
    Props = [{handlers, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {succeed, sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

succeed_nosub(_Config) ->
    Props = [{handlers, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {succeed, no_sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = undefined,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

fail_sub(_Config) ->
    Props = [{handlers, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {fail, sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = true,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

fail_nosub(_Config) ->
    Props = [{handlers, [rules_sub_test]}],
    [{_Id, Pid}] = start([{undefined, Props}]),
    ?WAIT100,
    egre_object:attempt_after(0, Pid, {fail, no_sub}, _ShouldSub = false),
    ?WAIT100,
    StoredProps = egre_object:props(Pid),
    Expected = undefined,
    Result = proplists:get_value(sub, StoredProps),
    ?assertEqual(Expected, Result).

wait_for(_NoUnmetConditions = [], _) ->
    ok;
wait_for(Conditions, Count) when Count =< 0 ->
    {Failures, _} = lists:unzip(Conditions),
    ct:fail("Failed waiting for conditions: ~p~n", [Failures]);
wait_for(Conditions, Count) ->
    {Descriptions, _} = lists:unzip(Conditions),
    ct:pal("Checking conditions: ~p~n", [Descriptions]),
    timer:sleep(1000),
    {_, ConditionsUnmet} = lists:partition(fun run_condition/1, Conditions),
    wait_for(ConditionsUnmet, Count - 1).

run_condition({_Desc, Fun}) ->
    Fun().

wait_value(ObjectId, Key, ExpectedValue, Count) ->
    WaitFun =
        fun() ->
            val(Key, ObjectId)
        end,
    true = wait_loop(WaitFun, ExpectedValue, Count).

wait_loop(Fun, ExpectedValue, _Count = 0) ->
    ct:pal("Mismatched function result:~n\tFunction: ~p~n\tResult: ~p",
           [erlang:fun_to_list(Fun), ExpectedValue]),
    false;
wait_loop(Fun, ExpectedValue, Count) ->
    case Fun() == ExpectedValue of
        true ->
            true;
        false ->
            ?WAIT100,
            wait_loop(Fun, ExpectedValue, Count - 1)
    end.

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

start(Objects) ->
    IdPids = [{Id, start_obj(Id, Props)} || {Id, Props} <- Objects],
    [egre_object:populate(Pid, IdPids) || {_, Pid} <- IdPids],
    timer:sleep(100),
    IdPids.

start_obj(Id, Props) ->
    {ok, Pid} = supervisor:start_child(egre_object_sup, [Id, Props]),
    Pid.

attempt(Config, Target, Message) ->
    TestObject = proplists:get_value(test_object, Config),
    TestObject ! {attempt, Target, Message}.

assert_ct_test_process_mailbox_empty() ->
    receive
        X ->
            ct:pal("~p:~p: CT test process got message: ~p~n", [?MODULE, ?FUNCTION_NAME, X]),
            fail
        after 0 ->
            ok
    end.

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
