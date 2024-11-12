-type proplist() :: [{atom(), any()}].
-type source() :: any().
-type type() :: any().
-type target() :: any().
-type context() :: any().
-type vector() :: any().


-record(object,
        {id :: string(),
         pid :: pid(),
         icon :: atom(),
         properties :: list()}).

-record(dead_pid_subscription,
        {subscriber :: pid(),
         dead_pid :: pid()}).

-record(replacement_pid,
        {old_pid :: pid(),
         new_pid :: pid()}).

-record(result,
        {result = succeed :: atom(),
         subscribe = true :: boolean(),
         event :: undefined | tuple(),
         props = [] :: list(),
         log = [] :: list(),
         context = undefined :: undefined | map()}).

-define(EVENT, event_type).
-define(SOURCE, event_source).
-define(TARGET, event_target).
