%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([all/0]).

-export([init_per_suite/1]).
-export([end_per_suite/1]).
-export([init_per_testcase/2]).
-export([end_per_testcase/2]).

-export([level_1_call_no_args/1]).

all() ->
    [level_1_call_no_args].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

level_1_call_no_args(Config) ->
    DataDir = proplists:get_value(data_dir, Config),
    %PrivDir = proplists:get_value(priv_dir, Config),

    {ok, CWD} = file:get_cwd(),
    os:putenv("EGRE_PARSE_TRANSFORM_OUT_DIR", CWD ++ "/"),

    %% CWD is the logs/ct_run... dir
    {ok, egre_protocol_ast_translate} =
        compile:file(DataDir ++ "/egre_protocol_ast_translate.erl"),

    {ok, egre_protocol_id_transform} =
        compile:file(DataDir ++ "/egre_protocol_id_transform.erl"),

    {ok, level_1_call_no_args_in} =
        compile:file(DataDir ++ "/level_1_call_no_args_in.erl",
                     [{parse_transform, egre_protocol_ast_translate}]),

    {ok, level_1_call_no_args_out} =
        compile:file(DataDir ++ "/level_1_call_no_args_out.erl",
                     [{parse_transform, egre_protocol_id_transform}]),

    X = compile:env_compiler_options(),
    ct:pal("~p:~p: X~n\t~p~n", [?MODULE, ?FUNCTION_NAME, X]),

    {ok, FileIn} = file:read_file("level_1_call_no_args_in"),
     ct:pal("~p:~p: FileIn~n\t~p~n", [?MODULE, ?FUNCTION_NAME, FileIn]),
    {ok, FileOut} = file:read_file("level_1_call_no_args_out"),
     ct:pal("~p:~p: FileOut~n\t~p~n", [?MODULE, ?FUNCTION_NAME, FileOut]),
    ?assertEqual(FileIn, FileOut).
