-module(egre_protocol_args_inference).

-export([infer/3]).

% CustomData can be:
% #{}
% #{foo := bar}
% #{foo := {body_part, Pid, BodyPart, Ref}

infer(attempt, _Args = [{tuple, [_CustomData = {map, []}, _, _, _]}], _PropertyTypes) ->
    _NoCustomDataTypesInferred = #{};
infer(attempt, _Args = [{tuple, [_CustomData = {map, Binds}, _, _, _]}], PropertyTypes) ->
    {TypeMap, _} = lists:foldl(fun custom_data_bind_inference/2, {#{}, PropertyTypes}, Binds),
    TypeMap;
infer(_, _, _) ->
    _NoCustomDataTypesInferred = #{}.

custom_data_bind_inference({map_field_exact, {atom, Field}, {var, Var}},
                           Acc = {TypeMap, PropertyTypes}) ->
    case PropertyTypes of
        #{Field := Type} ->
            {TypeMap#{Var => Type}, PropertyTypes};
        _ ->
            Acc
    end;
custom_data_bind_inference(_UnrecognizedMapBind, Acc) ->
    Acc.
