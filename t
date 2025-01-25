#!/usr/bin/env bash

rm -rf logs/

rm test/level_*.beam

touch src/*
touch test/*
touch include/*

cp src/egre_protocol_parse_transform.erl \
   test/egre_protocol_parse_transform_SUITE_data/

#find test/ | xargs touch

# Compile all of the dependencies in case we're making changes here
# instead of in their own projects
make FULL=1 all deps

# run only cases specific on the command line, if any
if [[ -n "$1" ]]
then
  CASES="-case $*"
  echo "Running with ${CASES}"
else
  echo "Running all cases"
fi

# 2025-01-23 CM
# NOTE recon trace does not work with a single case
# Not sure why
# You can specify more than one case in all/0 and it works, but if you
# use a single -case on the command line, or a single function in all/0,
# it doesn't work.
# TODO: test if it's just the one case: case_expression_is_nested_case

# See erlang.mk
# Search for "CT_SUITES"
# erlang.mk automatically adds _SUITE to the filename
#CT_SUITES="egre_protocol_parse_transform egre_protocol_event_parsing" \
#CT_SUITES="egre_protocol_event_parsing" \
CT_SUITES="egre_protocol_parse_transform" \
CT_OPTS="-config test/test.config ${CASES} " \
make ct | tee  out

## Print all AST files
#for f in logs/ct_run*/*{in,out}
#do
#  echo -e "\n$f\n"
#  cat $f
#  echo -e "\n"
#done
