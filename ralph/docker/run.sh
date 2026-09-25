#!/usr/bin/env bash
# Runs the build loop in Docker, then fetches what it landed into local
# branches for review. Never touches main: a human fast-forwards it.
#
# Usage: ralph/docker/run.sh -n 5 -t 900      (arguments go to `ralph run`)
#
# Needs a Claude Code token in $RALPH_TOKEN_FILE (default
# ~/.config/fun-ci-ralph/oauth-token), made with `claude setup-token`.
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
token_file=${RALPH_TOKEN_FILE:-$HOME/.config/fun-ci-ralph/oauth-token}
out=${RALPH_OUT:-"$(dirname "$repo")/fun-ci.ralph-out/$(date +%Y%m%d-%H%M%S)"}
[ -r "$token_file" ] || { echo "run.sh: no token at $token_file (see header)" >&2; exit 2; }

docker build --quiet -t fun-ci-ralph -f "$repo/ralph/docker/Dockerfile" "$repo" >/dev/null
mkdir -p "$out"

# Exported, not passed as -e VAR=value, so the token never shows in `ps`.
CLAUDE_CODE_OAUTH_TOKEN=$(<"$token_file")
export CLAUDE_CODE_OAUTH_TOKEN
status=0
docker run --rm \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e RALPH_GIT_NAME="$(git -C "$repo" config user.name)" \
  -e RALPH_GIT_EMAIL="$(git -C "$repo" config user.email)" \
  ${RALPH_AGENT:+-e RALPH_AGENT} ${RALPH_GATE:+-e RALPH_GATE} \
  -v "$repo":/src:ro \
  -v "$out":/out \
  fun-ci-ralph "$@" || status=$?

if [ -f "$out/main.bundle" ]; then git -C "$repo" fetch --quiet "$out/main.bundle" "main:ralph/incoming"; fi
if [ -f "$out/rejected.bundle" ]; then git -C "$repo" fetch --quiet --force "$out/rejected.bundle" "refs/heads/ralph/rejected/*:refs/heads/ralph/rejected/*"; fi
echo "run.sh: loop exit $status; output in $out"
[ -f "$out/log.tsv" ] && cat "$out/log.tsv"
exit "$status"
