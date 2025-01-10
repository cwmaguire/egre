#!/usr/bin/env bash

rm -rf logs/

rm test/level_*.beam

touch src/*
touch test/*
touch include/*

cp src/egre_protocol_parse_transform.erl \
   test/egre_protocol_parse_transform_SUITE_data/

# run only cases specific on the command line, if any
if [[ -n "$1" ]]
then
  CASES="-case $*"
  echo "Running with ${CASES}"
else
  echo "Running all cases"
fi

# See erlang.mk
# Search for "CT_SUITES"
# erlang.mk automatically adds _SUITE to the filename
#CT_SUITES="egre_protocol_event_parsing" \
CT_SUITES="egre_protocol_parse_transform egre_protocol_event_parsing" \
CT_OPTS="${CASES} -config test/test.config " \
make ct | tee  out

## Print all AST files
#for f in logs/ct_run*/*{in,out}
#do
#  echo -e "\n$f\n"
#  cat $f
#  echo -e "\n"
#done
