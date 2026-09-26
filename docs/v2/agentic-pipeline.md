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

A worktree isolates git state; it is not a security sandbox. The agent runs
with skip-permissions, so the loop runs in Docker:

    ralph/docker/run.sh -n 5 -t 900

The container gets the host repo read-only, clones `main`, runs the loop on the
clone as a non-root user, and hands back a git bundle. It has no git
credentials, so it can't push. `run.sh` fetches the result into
`ralph/incoming` (and any `ralph/rejected/*` branches) without touching `main`;
a human reviews and runs `git merge --ff-only ralph/incoming`. If `main` moved on
the host meanwhile, rebase `ralph/incoming` first. The container still has
outbound network, and its commits are unsigned. It needs a Claude Code token
from `claude setup-token` in `~/.config/fun-ci-ralph/oauth-token`.

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

Background: `research/llm-tui-iteration.md` surveys how others let a model
design and tune terminal interfaces. This loop follows its recommendation:
deterministic scenarios, rendered images, measurements, and a human who
approves what ships.

### What the evaluator can see

Each observation answers a different question, so the evaluator gets all of
them, per scenario, from headless mode:

| Input | Answers |
|---|---|
| `frames.jsonl` (cell grid per frame) | Exact text, colour, selection, layout bounds |
| `frames/NNNN.png`, in order | Hierarchy, spacing, contrast, and motion read frame by frame |
| `sheet.png` (contact sheet) | The whole animation at a glance, side by side with references |
| `stats.json` | Why something looks wrong: luminance, dark space, hue spread, cells changed per frame, bytes per frame |

Never a GIF. Claude's vision input uses only the first frame of an animated
image, so a GIF would show the evaluator one still and let it pass judgement
on motion it never saw. Motion is judged from the ordered PNG frames, and
every frame of a one-shot animation is included (sampling at a fixed rate
misses short flashes).

### Objective gates (in `rake`, block merges)

From `stats.json` / `frames.jsonl` of every scenario at 60, 80, 120 and 200
columns:

- no row wider than the terminal; nothing wraps
- every one-shot animation ends within its declared frame count
- consecutive frames of an animation differ (a frozen animation fails)
- bytes per frame <= budget (flicker proxy); no full-screen clear except on resize
- only the 256-colour palette; every SGR is reset by end of row
- the board rows and the footer are never overdrawn by an animation
- every `frames/NNNN.png` decodes as an image of the expected pixel size, so
  the evaluator is known to receive pixels and not an unrendered file

### Evaluator (produces findings, never edits)

Reads the inputs above plus `docs/v2/tui-rubric.md`, which is derived from
`wireframe.md` and `docs/animation-design.md` and may point at reference
screenshots in `docs/v2/tui-references/`. The rubric separates animation that
reports state (a stage failed, the run passed) from decoration; the first must
be legible at a glance, the second must never hide status. Scores each
scenario on legibility, motion quality (easing, no jitter), restraint,
consistency with the wireframe, and delight. Correctness is the objective
gates' job; the evaluator judges preference.

Writes `ralph/polish/findings.md`: one finding per item, each tied to a
scenario and a frame range or image region, with a score and a concrete
suggestion.

### Iterator (one finding per iteration)

Takes the highest-impact open finding and works it like a tuner:

1. Name the parameters in the scene's code (`renderer/src/scenes/`) that
   bear on the finding (speed, length, colour ramp, easing, density).
2. Change one parameter at a time, render a small sweep of candidates, and
   compare them as labelled images against the finding and the rubric.
3. Use `stats.json` to explain the difference, not only to pick a winner.
4. If no parameter sweep can fix it because a mechanism is missing (no easing
   curve, no depth, a transition that doesn't exist), stop tuning: mark the
   finding `needs-design` with what is missing.

Edits are small changes to a scene's constants, leaving unrelated values
alone, or new painting code in `renderer/src/art/` when the finding is a
mechanism. The objective
gates run, and the commit carries `*.snap.new` files with the finding marked
`awaiting-approval`.

### Human approval

Visual snapshots are only accepted by a human (`cargo insta review`, or
`rake polish:approve`), after watching the change in a real terminal:
`fun-ci console --headless` output reconstructs the screen but can't show how
the intended terminal's font and repaint behave. The loop can propose
aesthetics; it can't approve its own. The evaluator re-scores after approval,
closing or reopening the finding.
