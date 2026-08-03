-define(SINGLE_PAIR,
        [{<<"mod">>, succeed,
          {{1,x},[{1,<<"_">>}],['_']},
          {{1,x},[{1,<<"Y">>}],[pid]}}]).

-define(NO_CYCLES,
        [{<<"mod">>, succeed,
          {{1,x},[{1,<<"_">>}],['_']},
          {{1,x},[{1,<<"Y">>}],[pid]}}]).
