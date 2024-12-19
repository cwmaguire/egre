%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([all/0]).

-export([init_per_suite/1]).
-export([end_per_suite/1]).
-export([init_per_testcase/2]).
-export([end_per_testcase/2]).

-export([level_1_call_no_args/1]).
-export([level_1_call_1_literal_arg/1]).

all() ->
    [level_1_call_no_args,
     level_1_call_1_literal_arg].

init_per_suite(Config) ->

    DataDir = proplists:get_value(data_dir, Config),
    %% CWD is the logs/ct_run... dir
    {ok, egre_protocol_ast_translate} =
        compile:file(DataDir ++ "/egre_protocol_ast_translate.erl"),

    {ok, egre_protocol_id_transform} =
        compile:file(DataDir ++ "/egre_protocol_id_transform.erl"),

    {ok, CWD} = file:get_cwd(),
    os:putenv("EGRE_PARSE_TRANSFORM_OUT_DIR", CWD ++ "/"),

    Config.

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

level_1_call_no_args(Config) ->
    {FileIn, FileOut} = compile(level_1_call_no_args, Config),
    ?assertEqual(FileIn, FileOut).

level_1_call_1_literal_arg(Config) ->
    {FileIn, FileOut} = compile(level_1_call_1_literal_arg, Config),
    ?assertEqual(FileIn, FileOut).

compile(Module, Config) ->
    In = atom_to_list(Module) ++ "_in",
    Out = atom_to_list(Module) ++ "_out",
    FileIn = In ++ ".erl",
    FileOut = Out ++ ".erl",
    ModuleIn = list_to_atom(In),
    ModuleOut = list_to_atom(Out),

    DataDir = proplists:get_value(data_dir, Config),

    InPath = DataDir ++ "/" ++ FileIn,
    {ok, ModuleIn} =
        compile:file(InPath, [{parse_transform, egre_protocol_ast_translate}]),

    OutPath = DataDir ++ "/" ++ FileOut,
    {ok, ModuleOut} =
        compile:file(OutPath, [{parse_transform, egre_protocol_id_transform}]),

    {ok, InData} = file:read_file(In),
    {ok, OutData} = file:read_file(Out),
    {InData, OutData}.
