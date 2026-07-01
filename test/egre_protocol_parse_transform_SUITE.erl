%% Copyright 2024, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_protocol_parse_transform_SUITE).

-include_lib("eunit/include/eunit.hrl").

-export([all/0]).

-export([init_per_suite/1]).
-export([end_per_suite/1]).
-export([init_per_testcase/2]).
-export([end_per_testcase/2]).

-export([level_1_call_no_args/1]).
-export([level_1_call_1_literal_arg/1]).
-export([level_1_call_1_var_arg/1]).
-export([level_2_call_no_args/1]).
-export([level_2_call_2_var_args/1]).
-export([level_2_call_1_fun_arg/1]).
-export([level_2_call_with_lc/1]).
-export([level_2_call_recursive/1]).
-export([level_1_decouple_disjunctions/1]).
-export([decouple_orelse/1]).
-export([decouple_andalso_orelse/1]).
-export([case_no_guards_1_clause/1]).
-export([case_no_guards_2_clauses/1]).
-export([case_1_guard_2_clauses/1]).
-export([case_2_guards_2_clauses/1]).
-export([case_2_clauses_with_2_guards_each/1]).
-export([case_nested/1]).
-export([case_expression_is_nested_case/1]).

% all() ->
%     [level_1_call_no_args,
%      level_1_call_1_literal_arg,
%      level_1_call_1_var_arg,
%      level_2_call_no_args,
%      level_2_call_2_var_args,
%      level_2_call_1_fun_arg,
%      level_2_call_with_lc,
%      level_2_call_recursive,
%      level_1_decouple_disjunctions,
%      decouple_orelse,
%      case_no_guards_1_clause,
%      case_no_guards_2_clauses,
%      case_1_guard_2_clauses,
%      case_2_guards_2_clauses,
%      case_2_clauses_with_2_guards_each,
%      case_nested,
%      case_expression_is_nested_case].

% all() -> [level_1_decouple_disjunctions, decouple_orelse].

all() -> [decouple_andalso_orelse].
% all() -> [decouple_orelse].
% all() -> [level_1_call_no_args].

% all() -> [level_1_decouple_disjunctions].

init_per_suite(Config) ->

    %egre_dbg:add(egre_protocol_parse_transform, inline_form),
    %egre_dbg:add(egre_protocol_parse_transform, clause_scope_paths),
    %egre_dbg:add(egre_protocol_parse_transform, scope_paths),
    %egre_dbg:add(egre_protocol_parse_transform, body_scope_paths),

    DataDir = proplists:get_value(data_dir, Config),
    %% CWD is the logs/ct_run... dir
    {ok, egre_protocol_parse_transform} =
        compile:file(DataDir ++ "/egre_protocol_parse_transform.erl"),

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

level_1_call_no_args(Config) -> test(?FUNCTION_NAME, Config).
level_1_call_1_literal_arg(Config) -> test(?FUNCTION_NAME, Config).
level_1_call_1_var_arg(Config) -> test(?FUNCTION_NAME, Config).
level_1_decouple_disjunctions(Config) -> test(?FUNCTION_NAME, Config).
decouple_orelse(Config) -> test(?FUNCTION_NAME, Config).
decouple_andalso_orelse(Config) -> test(?FUNCTION_NAME, Config).
level_2_call_no_args(Config) -> test(?FUNCTION_NAME, Config).
level_2_call_2_var_args(Config) -> test(?FUNCTION_NAME, Config).
level_2_call_1_fun_arg(Config) -> test(?FUNCTION_NAME, Config).
level_2_call_with_lc(Config) -> test(?FUNCTION_NAME, Config).
level_2_call_recursive(Config) -> test(?FUNCTION_NAME, Config).
case_no_guards_1_clause(Config) -> test(?FUNCTION_NAME, Config).
case_no_guards_2_clauses(Config) -> test(?FUNCTION_NAME, Config).
case_1_guard_2_clauses(Config) -> test(?FUNCTION_NAME, Config).
case_2_guards_2_clauses(Config) -> test(?FUNCTION_NAME, Config).
case_2_clauses_with_2_guards_each(Config) -> test(?FUNCTION_NAME, Config).
case_nested(Config) -> test(?FUNCTION_NAME, Config).
case_expression_is_nested_case(Config) -> test(?FUNCTION_NAME, Config).

test(FileName = FunctionName, Config) ->
    compare(FunctionName, compile(FileName, Config)).

compare(_Test, {Same, Same}) ->
    ok;
compare(Test, {ActualAst, ExpectedAst}) ->
    ExpectedPretty = iolist_to_binary(re:replace(ExpectedAst, <<"\n| ">>, <<"">>, [global])),
    ActualPretty = iolist_to_binary(re:replace(ActualAst, <<"\n| ">>, <<"">>, [global])),
    ct:pal("Expected vs Actual AST for ~p:~n~p~n~n~p~n", [Test, ExpectedPretty, ActualPretty]),
    ct:fail("Mismatched AST for ~p", [Test]).

compile(ModuleBaseName, Config) ->
    In = atom_to_list(ModuleBaseName) ++ "_in",
    Out = atom_to_list(ModuleBaseName) ++ "_out",

    {ok, InData} = compile_(In, egre_protocol_parse_transform, Config),
    {ok, OutData} = compile_(Out, egre_protocol_id_transform, Config),

    {InData, OutData}.

compile_(ModuleName, TransformModule, Config) ->
    Module = list_to_atom(ModuleName),

    DataDir = proplists:get_value(data_dir, Config),
    File = ModuleName ++ ".erl",
    Path = DataDir ++ File,

    Result = compile:file(Path, [{parse_transform, TransformModule}, return_errors]),
    case Result of
        {error, Errors, _Warnings} ->
            ct:fail("Compile error for ~p:~n~p~n", [File, Errors]);
        {ok, Module} ->
            file:read_file(ModuleName);
        Other ->
            ct:pal("~p:~p: Other~n\t~p~n", [?MODULE, ?FUNCTION_NAME, Other])
    end.
