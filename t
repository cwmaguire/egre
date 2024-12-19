#!/usr/bin/env bash

rm -rf logs/

cp src/egre_protocol_ast_translate.erl \
   test/egre_protocol_SUITE_data/

# run only cases specific on the command line, if any
if [ -n $1 ]
then
  CASES="-case $*"
  echo "Running with ${CASES}"
else
  echo "Running all cases"
fi

# See erlang.mk
# Search for "CT_SUITES"
# erlang.mk automatically adds _SUITE to the filename
CT_SUITES="egre_protocol" \
CT_OPTS="${CASES} -config test/test.config " \
make ct | tee  out
