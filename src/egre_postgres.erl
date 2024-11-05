-module(egre_postgres).

-include_lib("epgsql/include/epgsql.hrl").

-behaviour(gen_server).

-export([start_link/0]).
-export([insert/1]).
-export([wait_for_db/0]).

%% gen_server

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {conn :: pid(),
                statement :: epgsql:statement(),
                ref :: reference()}).

insert(Values) ->
    gen_server:cast(?MODULE, {insert, Values}).

wait_for_db() ->
    gen_server:call(?MODULE, wait_for_db).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server

init([]) ->
    {ok, Conn} = epgsqla:start_link(),
    io:format(user, "epgsql started: Conn = ~p~n", [Conn]),

    Ref = epgsqla:connect(Conn, "localhost", "egre", "egre", #{database => "egre"}),

    {ok, #state{conn = Conn, ref = Ref}}.

handle_call(wait_for_db, _From, State) ->
    {reply, ok, State};
handle_call(_Msg, _From, State) ->
    {reply, ignored, State}.

handle_cast({insert, Values},
            State = #state{conn = Conn,
                           statement = Statement = #statement{types = Types}})
  when is_list(Values) ->
    TypedParameters = lists:zip(Types, Values),
    epgsqla:prepared_query(Conn, Statement, TypedParameters),
    {noreply, State#state{ref = undefined}};
handle_cast(Msg, State) ->
    io:format(user, "Unrecognized cast: ~p, State: ~p", [Msg, State]),
    {noreply, State}.

handle_info({Conn, Ref, connected}, State = #state{conn = Conn, ref = Ref}) ->
    StatementRef = create_statement(Conn),
    {noreply, State#state{ref = StatementRef}};
handle_info({Conn, Ref, {ok, Statement = #statement{}}}, State = #state{conn = Conn, ref = Ref}) ->
    {noreply, State#state{statement = Statement, ref = undefined}};
handle_info({Conn, _Ref, {ok, _NumInserted}}, State = #state{conn = Conn}) ->
    {noreply, State};
handle_info(Info, State) ->
    io:format(user, "~p: ~p:handle_info(~p, State)~n", [self(), ?MODULE, Info]),
    {noreply, State}.

terminate(Reason, State = #state{conn = Conn}) ->
    io:format(user, "Terminating egre_postgres: ~p~n~p~n", [Reason, State]),
    epgsqla:close(Conn).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

create_statement(Conn) ->
    epgsqla:parse(Conn,
                  "insert_log",
                  "insert into log "
                  "(pid, stage, rules_module, message, owner, character)"
                  " values "
                  "($1, $2, $3, $4, $5, $6)",
                  []).
