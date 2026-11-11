#!/bin/sh
# Runs beside fast.sh, on what build.sh built.
# The rest of the gate (the checks on the repository itself first, since
# they take seconds), then the mutants in every line since the last commit
# whose slow stage passed here (refs/mutation/passed), or in this commit's
# own when that one is not behind it: while a slow suite runs, the commits
# that land skip theirs, and only the newest gets one when it ends.
base=$(git rev-parse -q --verify refs/mutation/passed)
git merge-base --is-ancestor "$base" "$1" 2>/dev/null || base="$1~1"
bundle exec rake policy integration rust:test contract:binary "mutation:changed[$base]" || exit
git update-ref refs/mutation/passed "$1"
