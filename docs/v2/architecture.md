# fun-ci 2.0 — Architecture and Decisions

Status: accepted as the working plan. Decisions can be revisited; each one says
what would make us change it.

## Goals

1. Ruby orchestrates, Rust renders the TUI. **Only rendering moves to Rust.**
2. intent-record's test and code-quality standards apply to the whole repo.
3. An agentic pipeline evaluates and iterates on the TUI and its animations.
4. Worktree isolation per commit — both for the pipelines fun-ci runs and for
   the agents that build fun-ci.

## The boundary

| Stays in Ruby | Moves to Rust (`fun-ci-renderer`) |
|---|---|
| `BoardData` (SQLite reads, paging) | Terminal ownership: raw mode, alt screen, resize, key reading |
| `KeyHandler` state: cursor, confirm, cancel | Layout, colour, truncation, header/footer/empty state |
| `StreakCounter`, `StageChangeDetector` (they decide *events*) | Formatting of durations, relative times, hashes |
| Cancelling runs, the refresh/poll policy | Spinner, every animation, frame timing |
| Spawning and supervising the renderer | The header's scenes and how they are painted |

Rule of thumb: Ruby decides **what is true**; Rust decides **how it looks**.
Ruby never emits an ANSI escape once 2.0 ships.

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

**Decision: visual review uses ordered PNG frames.** The polish loop's
evaluator is a vision model, and Claude reads only the first frame of an
animated image, so headless mode renders each frame to PNG and the evaluator
reads them in order. Measurements in `stats.json` sit beside the images to
explain what looks wrong. Background in `research/llm-tui-iteration.md`.
*Revisit if* the evaluator moves to a model that takes video at every frame.

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

CI installs every built platform gem into an empty `GEM_HOME` and runs
`fun-ci console --headless --scenario empty` against it (lesson from
agent-tome / agent-chat: whatever no clean install checks, drifts).

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

## Worktree isolation for agents

Agents building fun-ci run one iteration per throwaway worktree; the gate runs
again *outside* the agent's control, and only a green iteration fast-forwards
the integration branch. See [`agentic-pipeline.md`](agentic-pipeline.md).

## Quality standards (from intent-record)

- `rake` (default) = Ruby tests → Rust tests (`cargo test`) → rubocop → clippy.
  Mutation lanes (`rake mutation`, `rake mutation:rust`) run in CI, not on
  every commit. All must be green before a commit.
- RuboCop: `Metrics/MethodLength` 7, `Metrics/BlockNesting` 2 (count blocks),
  `Metrics/ParameterLists` 4. Existing fun-ci limits stay: 150 lines per file,
  4 instance variables per class.
- Clippy: `-D warnings`, `pedantic`, `too-many-lines-threshold = 15`,
  `too-many-arguments-threshold = 4`, `cognitive-complexity-threshold = 10`.
- Mutation: mutineer ≥ 90 (Ruby), cargo-mutants ≥ 90 % caught (Rust, computed
  from `mutants.out/outcomes.json`).
- CI matrix: Ruby 3.2, 3.3, 3.4, 4.0 × stable Rust.
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

## Migrating the renderer: differential first

The Ruby renderer is the oracle until the Rust one reaches parity:

1. Scenario files (`contract/scenarios/*.jsonl`) describe board states, events
   and ticks **in protocol v1 messages** plus the headless-only `tick` and
   `resize` (format in `renderer-protocol.md`). The Rust headless mode replays
   the same files, so there is one scenario format, not two.
2. A Ruby capture tool drives today's `BoardRenderer` and `AnimationRenderer`,
   wired as `fun-ci console` wires them, with the scenario clock, and records
   the bytes of each frame → `contract/golden/<scenario>/NNNN.bytes`. A test in
   the gate re-captures and compares, so the golden corpus also guards the Ruby
   renderer against drift while §0 refactors it.
3. The Rust test suite feeds both the golden bytes and its own output through
   the `vt100` crate and compares **cell grids** (text + colour + attributes),
   not bytes, so the Rust side is free to emit fewer, smarter escapes.
4. When every scenario matches, the Ruby renderer is deleted and the golden
   files become `insta` snapshots owned by Rust. From then on visual changes
   are deliberate snapshot updates approved by a human.

## Breaking changes in 2.0

- `fun-ci-trigger` and `fun-ci-tui` executables are removed.
- The pre-commit hook becomes post-commit.
- Ruby ≥ 3.2 stays; Rust is only needed to build from source.
