-module(egre_postgres).

-include_lib("epgsql/include/epgsql.hrl").
-include("postgres.hrl").

-behaviour(gen_statem).

-export([start_link/0]).
-export([insert_log/1]).
-export([insert_pid_id/1]).
-export([wait_ready/0]).
-export([wait_done/1]).

-export([init/1]).
-export([callback_mode/0]).

-export([connecting/3]).
-export([log_table/3]).
-export([pid_id_table/3]).
-export([pid_id_index/3]).
-export([log_statement/3]).
-export([pid_id_statement/3]).
-export([logging/3]).

-record(data, {conn :: pid(),
               ref :: reference(),
               log_statement :: epgsql:statement(),
               pid_id_statement :: epgsql:statement(),
               from :: pid()}).

insert_log(Values) ->
    gen_statem:cast(?MODULE, {insert_log, Values}).

insert_pid_id(Values) ->
    gen_statem:cast(?MODULE, {insert_pid_id, Values}).

wait_ready() ->
    gen_statem:call(?MODULE, wait_ready).

wait_done(TimeoutMillis) ->
    gen_statem:call(?MODULE, {wait_for_db, TimeoutMillis}).

start_link() ->
    gen_statem:start_link({local, ?MODULE}, ?MODULE, [], []).

callback_mode() ->
    [state_functions, state_enter].

init([]) ->
    {ok, Conn} = epgsqla:start_link(),
    io:format(user, "epgsql started: Conn = ~p~n", [Conn]),
    {ok, connecting, #data{conn = Conn}}.

connecting(enter, _, Data = #data{conn = Conn}) ->
    Ref = epgsqla:connect(Conn, "localhost", "egre", "egre", #{database => "egre"}),
    {keep_state, Data#data{ref = Ref}};
connecting(info, {Conn, ConnRef, connected}, Data = #data{conn = Conn, ref = ConnRef}) ->
    {next_state, log_table, Data#data{ref = undefined}};
connecting(_, _Event, #data{}) ->
    {keep_state_and_data, postpone}.

log_table(enter, _, Data = #data{conn = Conn}) ->
    ColumnNames = [atom_to_binary(Col) || Col <- ?LOG_COLUMNS],
    Ref = create_log_table(Conn, ColumnNames),
    {keep_state, Data#data{ref = Ref}};
log_table(info, {Conn, LogTableRef, _Result}, Data = #data{conn = Conn, ref = LogTableRef}) ->
    {next_state, pid_id_table, Data#data{ref = undefined}};
log_table(_, _Event, _Data) ->
    {keep_state_and_data, [postpone]}.

pid_id_table(enter, _, Data = #data{conn = Conn}) ->
    ColumnNames = [atom_to_binary(Col) || Col <- ?PID_ID_COLUMNS],
    Ref = create_pid_id_table(Conn, ColumnNames),
    {keep_state, Data#data{ref = Ref}};
pid_id_table(info, {Conn, PidIdRef, _Result}, Data = #data{conn = Conn, ref = PidIdRef}) ->
    {next_state, pid_id_index, Data#data{ref = undefined}};
pid_id_table(_, _Event, _Data) ->
    {keep_state_and_data, [postpone]}.

pid_id_index(enter, _, Data = #data{conn = Conn}) ->
    Ref = create_pid_id_index(Conn),
    {keep_state, Data#data{ref = Ref}};
pid_id_index(info, {Conn, PidIdIndexRef, _Result}, Data = #data{conn = Conn, ref = PidIdIndexRef}) ->
    {next_state, log_statement, Data#data{ref = undefined}};
pid_id_index(_, _Event, _Data) ->
    {keep_state_and_data, [postpone]}.

log_statement(enter, _, Data = #data{conn = Conn}) ->
    ColumnNames = [atom_to_binary(Col) || Col <- ?LOG_COLUMNS],
    Ref = create_log_insert_statement(Conn, ColumnNames),
    {keep_state, Data#data{ref = Ref}};
log_statement(info, {Conn, LogStatementRef, {ok, Statement}}, Data = #data{conn = Conn, ref = LogStatementRef}) ->
    {next_state, pid_id_statement, Data#data{ref = undefined, log_statement = Statement}};
log_statement(info, {Conn, LogStatementRef, _Other}, #data{conn = Conn, ref = LogStatementRef}) ->
    {stop, <<"failed to create log statement">>};
log_statement(_, _Event, _Data) ->
    {keep_state_and_data, [postpone]}.

pid_id_statement(enter, _, Data = #data{conn = Conn}) ->
    ColumnNames = [atom_to_binary(Col) || Col <- ?PID_ID_COLUMNS],
    Ref = create_pid_id_insert_statement(Conn, ColumnNames),
    {keep_state, Data#data{ref = Ref}};
pid_id_statement(info, {Conn, PidIdStatementRef, {ok, Statement}}, Data = #data{conn = Conn, ref = PidIdStatementRef}) ->
    {next_state, logging, Data#data{ref = undefined, pid_id_statement = Statement}};
pid_id_statement(info, {Conn, PidIdStatementRef, _Other}, #data{conn = Conn, ref = PidIdStatementRef}) ->
    {stop, <<"failed to create pid_id statement">>};
pid_id_statement(_, _Event, _Data) ->
    {keep_state_and_data, [postpone]}.

logging(timeout, _, Data = #data{from = From}) ->
    {keep_state, Data#data{from = undefined}, [{reply, From, done}]};
logging(Whatever, Event, Data = #data{from = undefined}) ->
    logging_(Whatever, Event, Data);
logging(EventType, Event, Data) ->
    TimeoutMillis = 2000,
    case logging_(EventType, Event, Data) of
        keep_state_and_data ->
            {keep_state_and_data, [{timeout, TimeoutMillis, foo}]};
        {keep_state, Data} ->
            {keep_state, Data, [{timeout, TimeoutMillis, foo}]};
        Other ->
            Other
    end.

logging_(enter, _, _) ->
    keep_state_and_data;

logging_({call, From = {_Pid, _Ref}}, wait_ready, #data{}) ->
    {keep_state_and_data, [{reply, From, done}]};
logging_({call, From = {_Pid, _Ref}}, {wait_for_db, _Millis}, Data) ->
    {keep_state, Data#data{from = From}, [{timeout, 500, bar}]};

logging_(cast, {insert_log, Values}, #data{conn = Conn, log_statement = Statement})
  when is_list(Values) ->
    insert(Values, Statement, Conn),
    keep_state_and_data;
logging_(cast, {insert_pid_id, Values}, #data{conn = Conn, pid_id_statement = Statement})
  when is_list(Values) ->
    insert(Values, Statement, Conn),
    keep_state_and_data;

logging_(info, {Conn, _Ref, {ok, _RowsInserted}}, #data{conn = Conn}) ->
    keep_state_and_data;
logging_(info, {Conn, _Ref, {error, Error}}, #data{conn = Conn}) ->
    io:format("~p Logging error: ~p", [self(), Error]),
    keep_state_and_data;

logging_(cast, {insert_log, Values}, #data{conn = Conn, log_statement = Statement})
  when is_list(Values) ->
    insert(Values, Statement, Conn),
    keep_state_and_data;
logging_(cast, {insert_pid_id, Values}, #data{conn = Conn, pid_id_statement = Statement})
  when is_list(Values) ->
    insert(Values, Statement, Conn),
    keep_state_and_data;

logging_(Type, Event, _Data) ->
    io:format("~p:~p: Unexpected Type ~p and Event ~p", [?MODULE, ?FUNCTION_NAME, Type, Event]),
    keep_state_and_data.

insert(Values, Statement = #statement{types = Types}, Conn) ->
    TypedParameters = lists:zip(Types, Values),
    epgsqla:prepared_query(Conn, Statement, TypedParameters).

create_log_insert_statement(Conn, Keys) ->
    Columns = lists:join(<<",">>, [Key || Key <- Keys]),
    Digits = lists:seq(1, length(Keys)),
    Params = lists:join(<<",">>, [[<<"$">>, integer_to_binary(Digit)] || Digit <- Digits]),
    epgsqla:parse(Conn,
                  _Name = "insert_log",
                  ["insert into log "
                   "(",
                   Columns,
                   ")"
                   " values "
                   "(",
                   Params,
                   ")"],
                  []).

create_pid_id_insert_statement(Conn, Keys) ->
    Columns = lists:join(<<",">>, [Key || Key <- Keys]),
    Digits = lists:seq(1, length(Keys)),
    Params = lists:join(<<",">>, [[<<"$">>, integer_to_binary(Digit)] || Digit <- Digits]),
    epgsqla:parse(Conn,
                  _Name = "insert_pid_id",
                  ["insert into pid_id "
                   "(",
                   Columns,
                   ")"
                   " values "
                   "(",
                   Params,
                   ") "
                   "on conflict (tag, pid) do nothing;"], %% could use "on conflict on constraint tag_pid do nothing"
                  []).

create_log_table(Conn, Columns) ->
    ColumnSpecs = [[", ", Col, " text"] || Col <- Columns],

    epgsqla:squery(Conn,
                   ["create table if not exists log ("
                    "id serial primary key, "
                    "timestamp timestamp default current_timestamp ",
                    ColumnSpecs,
                    ");"]).

create_pid_id_table(Conn, Keys) ->
    Columns = [[", ", Key, " text"] || Key <- Keys],

    epgsqla:squery(Conn,
                   ["create table if not exists pid_id ("
                    "id serial primary key, "
                    "timestamp timestamp default current_timestamp ",
                    Columns,
                    ")"]).

create_pid_id_index(Conn) ->
    epgsqla:squery(Conn,
                   ["create unique index if not exists tag_pid on pid_id(tag, pid);"]).
