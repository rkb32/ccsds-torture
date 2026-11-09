#!/usr/bin/env bash
# Flags fuzz runs whose libFuzzer elapsed time exceeds their budget by more than 60 s.
# Such overruns point to host sleep (suspended time still counts on the wall clock).
# Usage: checkbudget.sh <budget_seconds> <run.log>...
budget=$1; shift
for f in "$@"; do
  s=$(grep -o 'Done [0-9]* runs in [0-9]* second' "$f" | grep -o '[0-9]*' | tail -1)
  if [ -z "$s" ]; then echo "NO-DONE  $f"; continue; fi
  if [ "$s" -gt $((budget + 60)) ]; then
    echo "OVER     $f elapsed=${s}s budget=${budget}s"
  else
    echo "ok       $f elapsed=${s}s"
  fi
done
