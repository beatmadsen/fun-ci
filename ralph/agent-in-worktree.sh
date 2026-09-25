#!/usr/bin/env bash
# Runs one agent iteration in a throwaway git worktree and lands it only if
# the agent made exactly one commit and the gate is green.
#
# Usage (as Ralphify's agent command, prompt on stdin):
#   ralph/agent-in-worktree.sh < prompt.md
#
# Environment:
#   RALPH_AGENT  agent command, reads prompt on stdin
#                (default: claude -p --dangerously-skip-permissions)
#   RALPH_GATE   gate command run in the worktree (default: bundle exec rake)
#   RALPH_BASE   integration branch (default: branch checked out in main worktree)
#   RALPH_DIR    where iteration worktrees go (default: ../<repo>.ralph)
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
repo_name=$(basename "$repo_root")
agent=${RALPH_AGENT:-"claude -p --dangerously-skip-permissions"}
gate=${RALPH_GATE:-"bundle exec rake"}
base=${RALPH_BASE:-$(git -C "$repo_root" symbolic-ref --short HEAD)}
wt_root=${RALPH_DIR:-"$(dirname "$repo_root")/$repo_name.ralph"}
log="$repo_root/ralph/log.tsv"

mkdir -p "$wt_root"
taken() { git -C "$repo_root" show-ref --quiet "refs/heads/ralph/iter-$1" "refs/heads/ralph/rejected/iter-$1"; }
n=$(( $(wc -l < "$log" 2>/dev/null || echo 0) + 1 ))
while taken "$n"; do n=$((n + 1)); done
branch="ralph/iter-$n"
wt="$wt_root/iter-$n"
prompt=$(mktemp)
trap 'rm -f "$prompt"' EXIT
cat > "$prompt"

record() { printf '%s\t%s\t%s\t%s\n' "$n" "$1" "$2" "$3" >> "$log"; echo "ralph: iteration $n $1 $3" >&2; }

reject() {
  local reason=$1
  git -C "$repo_root" worktree remove --force "$wt"
  git -C "$repo_root" branch -m "$branch" "ralph/rejected/iter-$n"
  record rejected "$(git -C "$repo_root" rev-parse --short "ralph/rejected/iter-$n")" "$reason"
  exit 1
}

[ "$(git -C "$repo_root" symbolic-ref --short HEAD)" = "$base" ] || { echo "ralph: main worktree must have $base checked out" >&2; exit 2; }
start=$(git -C "$repo_root" rev-parse "$base")
git -C "$repo_root" worktree add --quiet -b "$branch" "$wt" "$start"

(cd "$wt" && bash -c "$agent" < "$prompt") || reject "agent exited $?"

commits=$(git -C "$wt" rev-list --count "$start..HEAD")
[ "$commits" -eq 1 ] || reject "expected exactly 1 commit, got $commits"
[ -z "$(git -C "$wt" status --porcelain)" ] || reject "uncommitted changes left behind"

(cd "$wt" && bash -c "$gate") > "$wt_root/iter-$n.gate.log" 2>&1 || reject "gate red (see $wt_root/iter-$n.gate.log)"

[ "$(git -C "$repo_root" rev-parse "$base")" = "$start" ] || reject "$base moved during the iteration"
git -C "$repo_root" merge --quiet --ff-only "$branch"
sha=$(git -C "$repo_root" rev-parse --short HEAD)
subject=$(git -C "$repo_root" log -1 --format=%s)
git -C "$repo_root" worktree remove --force "$wt"
git -C "$repo_root" branch -d "$branch" >/dev/null
rm -f "$wt_root/iter-$n.gate.log"
record landed "$sha" "$subject"
