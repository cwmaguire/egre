-module(egre_protocol_id_transform).

-export([parse_transform/2]).

parse_transform(Forms = [FilenameAttribute | _], _Options) ->
    Filename = filename(FilenameAttribute),
    file:open("test/forms/" ++ Filename, [write]),
    Forms.

filename({attribute, _, file, {Filename, _}}) ->
    filename:rootname(filename:basename(Filename)).
