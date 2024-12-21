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
    Test = level_1_call_no_args,
    compare(Test, compile(Test, Config)).

level_1_call_1_literal_arg(Config) ->
    %egre_dbg:add(egre_protocol_ast_translate, rename_form_args),
    Test = level_1_call_1_literal_arg,
    compare(Test, compile(Test, Config)).

compare(_Test, {Same, Same}) ->
    ok;
compare(Test, {ActualAst, ExpectedAst}) ->
    ExpectedPretty = iolist_to_binary(re:replace(ExpectedAst, <<"\n| ">>, <<"">>, [global])),
    ActualPretty = iolist_to_binary(re:replace(ActualAst, <<"\n| ">>, <<"">>, [global])),
    ct:pal("Expected vs Actual AST for ~p:~n~p~n~p~n", [Test, ExpectedPretty, ActualPretty]),
    ct:fail("Mismatched AST for ~p", [Test]).

compile(Module, Config) ->
    In = atom_to_list(Module) ++ "_in",
    Out = atom_to_list(Module) ++ "_out",
    FileIn = In ++ ".erl",
    FileOut = Out ++ ".erl",
    ModuleIn = list_to_atom(In),
    ModuleOut = list_to_atom(Out),

    DataDir = proplists:get_value(data_dir, Config),

    InPath = DataDir ++ FileIn,
    ct:pal("~p:~p: InPath~n\t~p~n", [?MODULE, ?FUNCTION_NAME, InPath]),
    Result1 = compile:file(InPath, [{parse_transform, egre_protocol_ast_translate}, return_errors]),
    case Result1 of
        {error, Errors1, _Warnings1} ->
            ct:pal("Compile error for ~p:~n~p~n", [FileIn, Errors1]);
        {ok, ModuleIn} ->
            ok;
        Other1 ->
            ct:pal("~p:~p: Other~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Other1])
    end,

    OutPath = DataDir ++ "/" ++ FileOut,
    Result2 = compile:file(OutPath, [{parse_transform, egre_protocol_id_transform}, return_errors]),
    case Result2 of
        {error, Errors2, _Warnings2} ->
            ct:pal("Compile error for ~p:~n~p~n", [FileOut, Errors2]);
        {ok, ModuleOut} ->
            ok;
        Other2 ->
            ct:pal("~p:~p: Other~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Other2])
    end,

    {ok, InData} = file:read_file(In),
    {ok, OutData} = file:read_file(Out),
    {InData, OutData}.
