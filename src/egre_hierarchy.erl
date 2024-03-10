%% Copyright 2022, Chris Maguire <cwmaguire@protonmail.com>
-module(egre_hierarchy).

-export([new/1]).
-export([insert/2]).
-export([is_descendent/2]).
%-export([is_descendent/3]).

new(Parent) ->
    {Parent, []}.

insert({Parent, Children}, NewParentChild) ->
    insert({Parent, Children, _PostChildren = []}, NewParentChild);
insert({Parent, PreChildren, PostChildren}, {Parent, NewChild}) ->
    {ok, {Parent, [{NewChild, []} | PreChildren] ++ PostChildren}};
insert({_, _PreChildren = [], _}, _) ->
    undefined;
insert({Parent, [Child0 | PreChildren], PostChildren},
       NewParentChild = {_NotParent, NewChild}) ->
    ct:pal("Inserting child ~p into ~p~n", [NewChild, Child0]),
    case insert(Child0, NewParentChild) of
        {ok, Child1} ->
            ct:pal("Inserted child ~p into ~p to get ~p~n", [NewChild, Child0, Child1]),
            {ok, {Parent, [Child1 | PreChildren] ++ PostChildren}};
        _ ->
            ct:pal("Did not insert child ~p into ~p~n", [NewChild, Child0]),
            ct:pal("Inserting ~p into head of ~p~n", [NewParentChild, PreChildren]),
            insert({Parent, PreChildren, [Child0 | PostChildren]}, NewParentChild)
    end.


%% Why do I preserve the parent in the depth-first tree search?

is_descendent(_Hierarchy = {TopObject, _}, TopObject) ->
    false;
is_descendent(_Hierarchy = {_, Children}, Obj) ->
    is_descendent_(Children, Obj).

is_descendent_([], _) ->
    false;
is_descendent_([{Child, _} | _Siblings], Child) ->
    true;
is_descendent_([{_, GrandChildren} | Siblings], Obj) ->
    is_descendent(GrandChildren, Obj) orelse
    is_descendent(Siblings, Obj).
