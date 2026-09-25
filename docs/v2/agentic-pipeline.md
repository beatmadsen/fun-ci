# Agentic pipeline

Two loops, one mechanism.

| Loop | Goal | Unit of work | Input | Stop |
|---|---|---|---|---|
| **build** (`ralph/build/`) | Implement the 2.0 roadmap | One acceptance test (`AT-x.y`) | `docs/v2/acceptance-tests.md`, `ralph/build/progress.md` | `ralph/build/DONE` |
| **polish** (`ralph/polish/`) | Make the TUI and animations good | One finding | Headless renders + rubric | No open findings above threshold, or iteration budget |

Both run under Ralphify with `ralph/agent-in-worktree.sh` as the `agent`
command. Paths are relative to the repo root — nothing is hard-coded.

## One iteration, one worktree

`ralph/agent-in-worktree.sh` receives the rendered prompt on stdin and:

1. Creates `../<repo>.ralph/iter-<n>` as a new worktree on a fresh branch
   `ralph/iter-<n>`, starting from the integration branch (`RALPH_BASE`,
   default: the branch checked out in the main worktree).
2. Runs the agent (`RALPH_AGENT`, default
   `claude -p --dangerously-skip-permissions`) **inside that worktree** with the
   prompt on stdin.
3. Refuses the iteration unless the agent made **exactly one** commit (the
   one-unit-of-work rule is enforced, not just requested).
4. Runs the gate itself (`RALPH_GATE`, default `bundle exec rake`) inside the
   worktree. The agent's own claim that tests pass is not trusted.
5. Green → `git merge --ff-only` into the integration branch in the main
   worktree. Red or no commit → the branch is kept as `ralph/rejected/iter-<n>`
   for inspection and nothing lands.
6. Removes the worktree. Appends one line to `ralph/log.tsv`
   (`iteration  verdict  sha  subject`).

Why: the agent can wreck its worktree without touching the integration branch;
every commit on the integration branch passed a gate the agent didn't run; and
a human can review `ralph/rejected/*` to see where the loop struggles.

Note: a worktree is isolation for git state, not a security sandbox. Run the
loop inside a container or VM if the agent has skip-permissions.

## Build loop rules (summary — full text in `ralph/build/RALPH.md`)

- Next unchecked item in `ralph/build/progress.md`; exactly one per iteration.
- Outer acceptance test RED → inner unit tests → GREEN → refactor under the
  RuboCop/Clippy limits → tick the item → one commit.
- Commit subject: behaviour in plain imperative English, prefixed `AT-x.y:`;
  body says why and how it was verified.
- A new gate lands with proof that it bites.
- After every 10 build iterations, one **refactor iteration**: no new
  behaviour, remove duplication the one-test-at-a-time rhythm created
  (lesson from agent-tome's 5 April cleanup).

## Polish loop

### Objective gates (in `rake`, block merges)

From `stats.json` / `frames.jsonl` of every scenario at 60, 80, 120 and 200
columns:

- no row wider than the terminal; nothing wraps
- every one-shot animation ends within its declared frame count
- bytes per frame ≤ budget (flicker proxy); no full-screen clear except on resize
- only the 256-colour palette; every SGR is reset by end of row
- the board rows and the footer are never overdrawn by an animation

### Evaluator (produces findings, never edits)

Reads `sheet.svg` contact sheets (rasterised to PNG for vision) plus
`docs/v2/tui-rubric.md`, which is derived from `wireframe.md` and
`docs/animation-design.md`. Scores each scenario on: legibility at a glance,
motion quality (easing, no jitter), restraint (animation never hides status),
consistency with the wireframe, and delight. Writes
`ralph/polish/findings.md`: one finding per item, with scenario, frame range,
score and a concrete suggestion.

### Iterator (one finding per iteration)

Takes the highest-impact open finding, changes animation data
(`renderer/animations/*.json`) or renderer code, re-renders, runs the objective
gates, and commits. Snapshot changes are included as `*.snap.new` files and the
finding is marked `awaiting-approval`.

### Human approval

Visual snapshots are only accepted by a human (`cargo insta review`, or
`rake polish:approve`). The loop can propose aesthetics; it can't approve its
own. The evaluator re-scores after approval, closing or reopening the finding.
