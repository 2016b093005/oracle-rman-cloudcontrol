#!/usr/bin/env bash
# Helper git script to add execute permissions on git files under ./sbin 

EXE_PATH="../sbin/*"

for file in `ls $EXE_PATH`
do
  echo git update-index --chmod=+x $file
done
