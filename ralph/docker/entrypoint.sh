#!/usr/bin/env bash
# Runs inside the container. Clones the read-only host repo, runs the build
# loop on the clone, and writes what it produced to /out:
#   /out/main.bundle       commits the loop landed on top of the host's main
#   /out/rejected.bundle   ralph/rejected/* branches, if any
#   /out/log.tsv           ralph/log.tsv
#   /out/gate-logs/        gate output of rejected iterations
# Arguments are passed to `ralph run ralph/build`.
set -euo pipefail

git config --global user.name "${RALPH_GIT_NAME:?}"
git config --global user.email "${RALPH_GIT_EMAIL:?}"
git config --global --add safe.directory /src
git clone --quiet --branch main /src /work/fun-ci
cd /work/fun-ci
bundle install --quiet

status=0
ralph run ralph/build "$@" || status=$?

base=$(git rev-parse origin/main)
if [ "$(git rev-parse main)" != "$base" ]; then git bundle create /out/main.bundle "$base..main"; fi
rejected=$(git for-each-ref --format='%(refname)' refs/heads/ralph/rejected)
if [ -n "$rejected" ]; then git bundle create /out/rejected.bundle $rejected; fi
cp ralph/log.tsv /out/ 2>/dev/null || true
mkdir -p /out/gate-logs && cp ../fun-ci.ralph/*.gate.log /out/gate-logs/ 2>/dev/null || true
exit "$status"
