-module(egre_postgres).

-include_lib("epgsql/include/epgsql.hrl").

-behaviour(gen_server).

-export([start_link/0]).
-export([insert/1]).

%% gen_server

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {conn :: pid(),
                statement :: epgsql:statement()}).

insert(Values) ->
    gen_server:cast(?MODULE, {insert, Values}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server

init([]) ->
    {ok, Conn} = epgsqla:start_link(),
    io:format(user, "epgsql started: Conn = ~p~n", [Conn]),

    Ref1 = epgsqla:connect(Conn, "localhost", "egre", "egre", #{database => "egre"}),

    receive {Conn_, Ref1_, connected}
      when Conn_ == Conn, Ref1_ == Ref1 ->
        io:format("Connected"),
        Conn_
    after 1000 ->
        timeout
    end,

    Ref2 = epgsqla:parse(Conn,
                         "insert_log",
                         "insert into log "
                         "(pid, rules_module, message)"
                         " values "
                         "($1, $2, $3)",
                         []),
    io:format(user, "Ref2 = ~p~n", [Ref2]),

    Statement = #statement{} =
        receive {Conn__, Ref2_, {ok, Statement_}} when Conn__ == Conn, Ref2_ == Ref2 ->
                    Statement_;
                Other ->
                    io:format(user, "Statement receive: Other = ~p~n", [Other])
        after 1000 ->
            io:format(user, "Statement receive timeout = ~p~n", [timeout])
        end,
     {ok, #state{conn = Conn,
                 statement = Statement}}.

handle_call(_Msg, _From, State) ->
    {reply, ignored, State}.

handle_cast({insert, Values},
            State = #state{conn = Conn,
                           statement = Statement = #statement{types = Types}})
  when is_list(Values) ->

    TypedParameters = lists:zip(Types, Values),
    io:format(user, "TypedParameters = ~p~n", [TypedParameters]),

    Ref3 = epgsqla:prepared_query(Conn, Statement, TypedParameters),
    io:format(user, "Ref3 = ~p~n", [Ref3]),

    Results =
        receive {Conn3, Ref3_, {ok, _Cols, Results_}} when Conn3 == Conn, Ref3_ == Ref3 ->
            Results_
        after 1000 ->
            timeout
        end,

    io:format(user, "Result = ~p~n", [Results]),

    {noreply, State};
handle_cast(Msg, State) ->
    io:format(user, "Unrecognized cast: ~p~n", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    io:format(user, "~p: ~p:handle_info(~p, State)~n", [self(), ?MODULE, Info]),
    {noreply, State}.

terminate(Reason, State = #state{conn = Conn}) ->
    io:format(user, "Terminating egre_postgres: ~p~n~p~n", [Reason, State]),
    Result = epgsqla:close(Conn),
    io:format(user, "Result = ~p~n", [Result]).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
