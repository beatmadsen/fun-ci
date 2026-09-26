# fun-ci architecture and decisions

How fun-ci is built and why: the split between the gem and the renderer, how
the renderer draws, how it is distributed, how pipelines are isolated, the
quality standards, and the agents that build and polish it. Each decision says
what would make us revisit it. What fun-ci is for, and what the developer
sees, is in [`design.md`](design.md).

## Engineering goals

These serve the product goals in `design.md` (all is well at a glance, and
fun).

1. Ruby orchestrates, Rust renders the console. **Only rendering is in Rust.**
2. intent-record's test and code-quality standards apply to the whole repo.
3. Agents build fun-ci from acceptance tests, and evaluate and iterate on the
   console and its animations.
4. Worktree isolation per commit, both for the pipelines fun-ci runs and for
   the agents that build fun-ci.

## The boundary

| Stays in Ruby | Moves to Rust (`fun-ci-renderer`) |
|---|---|
| `BoardData` (SQLite reads, paging) | Terminal ownership: raw mode, alt screen, resize, key reading |
| `KeyHandler` state: cursor, confirm, cancel | Layout, colour, truncation, header/footer/empty state |
| `StreakCounter`, `StageChangeDetector`, a run's milestones (they decide *events*) | Formatting of durations, relative times, hashes |
| Cancelling runs, the refresh/poll policy | Spinner, every animation, frame timing |
| Spawning and supervising the renderer | The header's scenes, which one plays, their queue, and how they are painted |

Rule of thumb: Ruby decides **what is true**; Rust decides **how it looks**.
Ruby never emits an ANSI escape.

**Decision — one tick, one frame.** Scenarios draw on `tick` only; `board`
just replaces state. The header's scenes play on a clock that only moves
forward, which in a scenario is the sum of its ticks, so a scenario still
maps one tick to one frame and the time of each frame is known.
*Revisit if* a scenario needs frames drawn between ticks.

**Decision — formatting lives in Rust.** Ruby sends raw values (epoch seconds,
milliseconds, full SHAs). "2m ago" must keep ticking between Ruby pushes, and
the renderer owns the clock, so it owns the formatting.
*Revisit if* formatting rules start needing data only Ruby has.

## Process model and protocol

`fun-ci console` (Ruby) spawns `fun-ci-renderer` as a child process.

- **stdin of the renderer:** JSON Lines from Ruby.
- **stdout of the renderer:** JSON Lines to Ruby.
- **The terminal:** the renderer opens `/dev/tty` itself. The pipes never carry
  terminal bytes, and a Ruby crash can't leave the terminal in raw mode because
  the renderer restores it on EOF.

Full message spec: [`renderer-protocol.md`](renderer-protocol.md).

**Decision — subprocess, not a native extension (magnus/rb-sys).** Crash
isolation, a renderer that runs and is tested headless on its own, and no C
toolchain at install time. *Revisit if* the per-frame JSON cost ever shows up
in a profile (it won't at 10 fps and ≤200 rows).

## Animations as scenes

In 1.x each animation was a Ruby module of ANSI strings, and 2.0 first carried
them over as JSON frames of text. The header's animations are now scenes:
Rust code in `renderer/src/scenes/` that paints a picture of light on a pixel
canvas for any moment and any width (`renderer/src/art/`: glows, streaks,
noise, sprites, a tone curve), which is then encoded as terminal cells. Each
cell covers 4x8 pixels and is drawn as whichever quadrant or lower-block glyph,
or up to three braille dots, in two colours, comes closest to them, in 24-bit
colour where the terminal has it.

**Decision: scenes in code, not frames as data.** Frames of text limit an
animation to one glyph and colour per cell and one width. Painting in pixels
gives gradients, soft light, anti-aliased shapes and particles, and a scene
fills the header at any width. The cost is that iterating on a scene means a
rebuild (seconds), not an edit to a data file.
*Revisit if* scenes need editing by people who do not write Rust.

**Decision: the header follows the run's milestones.** The console is
meant to be read from the corner of the eye, so the header plays one scene per
milestone a run reaches (lint passed, build passed, fast passed, passed, or
failed), each milestone drawing from its own pool, and queues them so none cuts
another short. Ruby works out the milestones from the stage rows and sends them
as events; the renderer picks, queues and plays the scenes. A run's status is
derived from its stages in one write, so the order in which the foreground
pipeline and the forked slow suite finish cannot change the verdict.
Requirements in `acceptance-tests.md` §7.
*Revisit if* the queue falls so far behind that a scene is taken for a later
run's.

**Decision: portable maths.** Scene code calls `art::math::Portable` (the
`libm` crate) instead of `f64::sin` and friends, which call the platform's
maths library and differ in the last bit between macOS and Linux; one such
difference tips a cell to another glyph, and a snapshot recorded on one
platform fails on the other. `tests/suite/portable_maths.rs` holds the rule.
*Revisit if* the snapshots stop pinning the header's cells.

## Distribution

**Decision — precompiled platform gems** (the tailwindcss-ruby pattern), built
in GitHub Actions for `x86_64-linux`, `aarch64-linux`, `x86_64-linux-musl`,
`arm64-darwin`, `x86_64-darwin`. The binary sits at
`libexec/fun-ci-renderer` inside the platform gem.

The plain `ruby`-platform gem also exists. Everything except `fun-ci console`
works without the renderer; `console` then prints how to get one
(`cargo install fun-ci-renderer`, or set `FUN_CI_RENDERER`).

Renderer lookup order: `FUN_CI_RENDERER` → bundled `libexec/` → `PATH`.
The renderer reports its protocol version in `ready`; a mismatch is a clear
error, never a garbled screen.

CI installs every built platform gem into an empty `GEM_HOME`, finds the
renderer through the gem's own lookup, and has it draw a frame headless
(`script/smoke-platform-gem.sh`; lesson from agent-tome and agent-chat:
whatever no clean install checks, drifts).

## Worktree isolation for pipelines

Problem in 1.x: the pre-commit hook records `git rev-parse HEAD` — the
*parent* commit — and the stages run in `Dir.pwd`, so they test a working tree
that is still being edited, under the wrong SHA. Pre-push's slow suite has the
same problem if you switch branches while it runs.

**Decisions:**

- The non-blocking hook becomes **post-commit** (the SHA exists then).
  `install-hooks` replaces a fun-ci pre-commit hook it owns; `check` warns
  about a legacy one. Pre-push stays.
- Each pipeline runs in a **pooled worktree** under
  `$(git rev-parse --git-common-dir)/fun-ci/worktrees/slot-N`. A run takes a
  free slot (lock file), `git checkout --detach <sha>`, `git clean -fd`
  (**not** `-x`: ignored caches like `vendor/bundle`, `node_modules`, `target/`
  survive, which keeps the 30 s build budget realistic), runs the stages there,
  and releases the slot when the **last** stage — normally the background slow
  suite — finishes.
- `StalePipelineCanceller` also releases the slots of the runs it cancels.
  Slots whose lock names a dead pid are reclaimed.
- Pool size defaults to 2 and is configurable in `.fun-ci/config`.

*Revisit if* per-slot caches turn out to go stale in ways `build.sh` can't fix.

## Quality standards (from intent-record)

- `rake` (default) is the gate: the Ruby tests, the Rust tests, the binary
  contract, RuboCop and Clippy; CLAUDE.md lists the lanes and a test holds the
  list. The mutation lanes (`rake mutation`, `rake mutation:rust`) run in CI,
  not on every commit.
- RuboCop: `Metrics/MethodLength` 7, `Metrics/BlockNesting` 2 (count blocks),
  `Metrics/ParameterLists` 4. Existing fun-ci limits stay: 150 lines per file,
  4 instance variables per class.
- Clippy: `-D warnings`, `pedantic`, `too-many-lines-threshold = 15`,
  `too-many-arguments-threshold = 4`, `cognitive-complexity-threshold = 10`.
- Mutation: mutineer ≥ 90 (Ruby), cargo-mutants ≥ 90 % caught (Rust, computed
  from `mutants.out/outcomes.json`).
- CI matrix: Ruby 3.2, 3.3, 3.4, 4.0, with the Rust release pinned in
  `renderer/rust-toolchain.toml` everywhere, so Clippy says the same on every
  machine.
- Every new gate lands with a commit that shows it bites (deliberate violation,
  gate fails, violation reverted).
- Tests are deterministic: injected clocks and runners, no sleeps, no polling.
- Tests are confined: temp dirs only, never `ENV`/home, guards fail the suite.
- **Deviation from intent-record:** no blanket no-subprocess rule — fun-ci is a
  process and git orchestrator. Tests that spawn processes or use real git live
  in `test/integration/process/` and only touch temp repositories; a Prism scan
  and a runtime guard enforce that no other test spawns.
- The renderer protocol has one set of contract fixtures
  (`contract/fixtures/*.jsonl`) that both suites read: Ruby asserts it *emits*
  them, Rust asserts it *accepts and renders* them. One `rake contract:binary`
  lane drives the real binary from Ruby and is part of `rake default`.
- Gemspec publishing metadata is pinned by a test (already true); `spec.files`
  comes from `git ls-files`.

## Visual changes are reviewed snapshot diffs

The Rust renderer reached parity with the Ruby one by replaying the same
scenarios through both and comparing cell grids (text, colour and attributes)
through the `vt100` crate; then the Ruby renderer was deleted. Since then the
scenarios in `contract/scenarios/` are `insta` snapshots owned by the Rust
suite, and a visual change is a snapshot diff a human reviews in the headless
PNGs and accepts on purpose.
*Revisit if* snapshots churn so often that review stops being real.

## Building fun-ci with agents

Two loops share one mechanism:

| Loop | Goal | Unit of work | Input | Stop |
|---|---|---|---|---|
| **build** (`ralph/build/`) | Implement the acceptance tests | One acceptance test (`AT-x.y`) | `acceptance-tests.md`, `ralph/build/progress.md` | `ralph/build/DONE` |
| **polish** (`ralph/polish/`, planned in §6 of the acceptance tests) | Make the console and animations good | One finding | Headless renders and a rubric | No open findings above threshold, or an iteration budget |

Both run under Ralphify with `ralph/agent-in-worktree.sh` as the agent command.

### One iteration, one worktree

`ralph/agent-in-worktree.sh` receives the rendered prompt on stdin and:

1. Creates `../<repo>.ralph/iter-<n>` as a new worktree on a fresh branch
   `ralph/iter-<n>`, starting from the integration branch (`RALPH_BASE`,
   default: the branch checked out in the main worktree).
2. Runs the agent (`RALPH_AGENT`, default
   `claude -p --dangerously-skip-permissions`) inside that worktree with the
   prompt on stdin.
3. Refuses the iteration unless the agent made exactly one commit.
4. Runs the gate itself (`RALPH_GATE`, default `bundle exec rake`) inside the
   worktree. The agent's own claim that tests pass is not trusted.
5. Green: `git merge --ff-only` into the integration branch. Red or no commit:
   the branch is kept as `ralph/rejected/iter-<n>` and nothing lands.
6. Removes the worktree and appends one line to `ralph/log.tsv`
   (`iteration  verdict  sha  subject`).

The agent can wreck its worktree without touching the integration branch,
every commit on it passed a gate the agent didn't run, and `ralph/rejected/*`
shows where the loop struggles.

A worktree isolates git state; it is not a security sandbox. The agent runs
with skip-permissions, so the loop runs in Docker:

    ralph/docker/run.sh -n 5 -t 900

The container gets the host repo read-only, clones `main`, runs the loop on the
clone as a non-root user, and hands back a git bundle. It has no git
credentials, so it can't push. `run.sh` fetches the result into
`ralph/incoming` (and any `ralph/rejected/*` branches) without touching `main`;
a human reviews and runs `git merge --ff-only ralph/incoming`, rebasing first if
`main` moved. The container still has outbound network, and its commits are
unsigned. It needs a Claude Code token from `claude setup-token` in
`~/.config/fun-ci-ralph/oauth-token`.

The build loop's rules are in `ralph/build/RALPH.md`, the prompt each
iteration gets: the next unchecked item in `progress.md`, acceptance test red
first, exactly one commit, and after every ten items one refactor iteration
with no new behaviour.

### The polish loop

**Decision: the evaluator sees ordered PNG frames, never a GIF.** Claude's
vision input uses only the first frame of an animated image, so a GIF would let
the evaluator judge motion it never saw. Headless mode renders every frame of a
scenario to PNG, with a contact sheet, the cell grid per frame
(`frames.jsonl`) and measurements (`stats.json`: luminance, dark space, hue
spread, cells changed and bytes per frame) that explain what looks wrong.
Background in [`research/llm-tui-iteration.md`](research/llm-tui-iteration.md).
*Revisit if* the evaluator moves to a model that takes video at every frame.

- **Objective gates** in `rake`, from every scenario at 60, 80, 120 and 200
  columns: nothing wider than the terminal, one-shot animations end within
  their frame count, consecutive frames differ, bytes per frame within budget,
  the rows and footer never overdrawn by an animation, every PNG decodes at the
  expected size.
- **The evaluator** reads those inputs and a rubric, and writes findings, one
  per item, each tied to a scenario and a frame range or region. It never
  edits. The rubric follows the two goals: an animation that reports state
  must read at a glance, and decoration must never hide status.
- **The iterator** takes the highest-impact finding and tunes like a sweep:
  name the parameters in the scene's code that bear on it, change one at a
  time, compare labelled candidates, and mark the finding `needs-design` when
  no parameter can fix it because a mechanism is missing.
- **A human approves** every snapshot change after watching it in a real
  terminal, since headless output can't show how the terminal's font and
  repaint behave. The loop can propose aesthetics; it can't approve its own.
