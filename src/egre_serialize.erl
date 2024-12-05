-module(egre_serialize).

-export([serialize/2]).

serialize(Bin, _SerializeFun) when is_binary(Bin) ->
    Bin;
serialize(List, SerializeFun) when is_list(List) ->
    case is_string(List) of
        true ->
            l2b(List);
        false ->
            [serialize(E, SerializeFun) || E <- List]
    end;
serialize(Timestamp = {Meg, Sec, Mic}, _)
  when is_integer(Meg), is_integer(Sec), is_integer(Mic)  ->
    ts2b(Timestamp);
serialize(Tuple, SerializeFun) when is_tuple(Tuple) ->
    List = tuple_to_list(Tuple),
    JoinedList = lists:join(<<" ">>, List),
    serialize(JoinedList, SerializeFun);
serialize(Ref, _) when is_reference(Ref) ->
    ref2b(Ref);
serialize(Pid, _) when is_pid(Pid) ->
    p2b(Pid);
serialize(Fun, _) when is_function(Fun) ->
    f2b(Fun);
serialize(Map, _) when is_map(Map) ->
    iolist_to_binary(io_lib:format("~p", [Map]));
serialize(Other, SerializeFun) ->
    SerializeFun(Other, fun(Value) -> serialize(Value, SerializeFun) end).

is_string([]) ->
    true;
is_string([X | Rest]) when is_integer(X),
                           X > 9, X < 127 ->
    is_string(Rest);
is_string(_) ->
    false.

l2b(List) when is_list(List) ->
    list_to_binary(List).

ref2b(Ref) when is_reference(Ref) ->
    list_to_binary(ref_to_list(Ref)).

p2b(Pid) when is_pid(Pid) ->
    case list_to_binary(pid_to_list(Pid)) of
        <<"<0.", Middle:3/binary, ".0>">> ->
            <<"|", Middle/binary, "|">>;
        <<"<0.", Middle:2/binary, ".0>">> ->
            <<"|", Middle/binary, "|">>;
        <<"<0.", Middle:1/binary, ".0>">> ->
            <<"|", Middle/binary, "|">>;
        Other ->
            Other
    end.

%a2b(Atom) when is_atom(Atom) ->
    %list_to_binary(atom_to_list(Atom)).

i2b(Int) when is_integer(Int) ->
    integer_to_binary(Int).

ts2b({Meg, Sec, Mic}) ->
    MegBin = i2b(Meg),
    SecBin = i2b(Sec),
    MicBin = i2b(Mic),
    <<"{", MegBin/binary, ",", SecBin/binary, ",", MicBin/binary, "}">>.

f2b(Fun) ->
  [{module, M}, {name, F}, {arity, A} | _] = erlang:fun_info(Fun),
  <<(atom_to_binary(M))/binary, ":",
    (atom_to_binary(F))/binary, "/",
    (i2b(A))/binary>>.
