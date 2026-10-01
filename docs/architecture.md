# fun-ci architecture and decisions

How fun-ci is built and why: the split between the gem and the renderer, how
the renderer draws, how it is distributed, how pipelines are isolated, the
quality standards, and how agents are to polish the console. Each decision says
what would make us revisit it. What fun-ci is for, and what the developer
sees, is in [`design.md`](design.md).

## Engineering goals

These serve the product goals in `design.md` (all is well at a glance, and
fun).

1. Ruby orchestrates, Rust renders the console. **Only rendering is in Rust.**
2. intent-record's test and code-quality standards apply to the whole repo.
3. Agents build fun-ci from acceptance tests, and evaluate and iterate on the
   console and its animations.
4. Each pipeline runs in a worktree of its own, checked out at its commit.

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
milliseconds, full SHAs). "2m" must keep ticking between Ruby pushes, and
the renderer owns the clock, so it owns the formatting.
*Revisit if* formatting rules start needing data only Ruby has.

**Decision: Ruby orders the rows.** The table shows a branch's newest run,
grouped by project with what needs you first (design.md, The console). Which
row comes next is also where `j` moves the cursor and what `c` cancels, and
the cursor lives in Ruby, so Ruby sends one run per branch in the order they
are shown, and the renderer draws them as they come, only choosing how much
air and how many passed rows fit.
*Revisit if* the renderer comes to own the cursor.

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

## Drawing the console

Each frame is composed in one ratatui buffer (`renderer/src/board_view/`): the
header's scene across the top 14 rows, the table and its footer below it, then
the effects over both. A ratatui `Terminal` compares the buffer with the last
frame's and hands the cells that changed to `AnsiBackend`
(`renderer/src/output/backend.rs`), which writes them as bytes: a cursor move
where a cell does not follow the one before, a style escape only where the
style changes, and colours in 24-bit or the nearest of xterm's 256. The live
session sends those bytes to the terminal and the headless replay keeps them,
so both draw the same bytes for the same state and clock. The table draws in
ratatui's own terms: the sky under the header is a widget filling each row
with its shade (`renderer/src/table/sky.rs`), each line is a `Line` of styled
spans placed at its columns, and the lead's block is a `Block` with a border
set of half blocks and quadrant corners, drawn behind the lead's lines
(`renderer/src/table/sheet.rs`).

**Decision: ratatui, drawing through a byte backend of our own.** ratatui
brings the buffer, the diff between frames and text measured by the columns it
fills, all of which the renderer used to do by hand: a line printer, a second
diff for the header alone, and names measured in characters, which put a
Chinese or Japanese branch name out of line with the rows around it. Its
crossterm backend writes to the terminal itself, and the renderer needs the
bytes, for the headless replay and its tests, in a colour depth it chooses. So
ratatui is built without its default features and draws into `AnsiBackend`.
A clear, a change of colour depth and a resize in one frame clear the screen
once, and a new depth clears it, since ratatui would redraw only the cells
that changed and leave the rest in the old colours.
*Revisit if* the renderer stops needing its frames as bytes.

**Decision: the table and the animations never see each other.** The table
(`renderer/src/table/`) draws its lines and says where it put each run's row,
the columns a row spans and the first of its marks; `board_view` hands that to
the animator as `Places`, and the effects land there. The animator (`animator/`, `animation/`,
`art/`, `scenes/`) knows where a mark is, never how the table drew it: an
effect changes the colour of the cell the table drew, and leaves its glyph and
the paper behind it alone. What both need, the model, the portable maths and
the output, has a module of its own. `tests/suite/decoupling.rs` fails on an
import either way.
*Revisit if* an effect needs more of the table than where a row and its marks are.

**Decision: stage effects are tachyonfx fades, timed by the clock.** An effect
on a stage's mark lights it in a colour of its own and fades, over a few
tenths of a second, back to however the row draws it: gold for a pass, amber
twice for a timeout, white on red cooling for a failure. tachyonfx plays each
on the one cell of its mark, which follows the board as rows move, and one at
a time on a mark. Effects and banners are timed by the animation clock, so a
key press or a board arriving between ticks does not speed them up. Each step
of an effect starts at the exact time it is due; a tachyonfx sequence would
start its next step a frame late whenever the last one ended on a frame.
tachyonfx is built without `std`, which would ease some curves with the
platform's `powf` and break the snapshots across platforms;
`tests/suite/portable_maths.rs` checks the build.
*Revisit if* an effect needs tachyonfx's own sequencing.

**Decision: row effects are tachyonfx too, and leave the marks alone.** A
run's end washes its row: `fx::fade_from` in the colour of how it ended, with
a left-to-right `SweepPattern`, so the colour drains across the row. A running
row carries a band of light, an `fx::effect_fn` repeated for as long as the
run runs and cancelled when it stops. Both play on a `RefRect` that follows
the row, and both skip the marks through a `CellFilter` on a second
`RefRect`, since the marks' own effects say which stage it was. The band
lifts colours in four steps and the headings' rules fade in six, so a frame
changes few cells and a 256-colour terminal shows no banding; the band's
maths is additions and rounding only, the same on every machine.
*Revisit if* a row effect needs to change a mark.

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

**Decision: portable maths.** Scene, art and table code calls
`maths::Portable` (the `libm` crate) instead of `f64::sin` and friends, which
call the platform's maths library and differ in the last bit between macOS
and Linux; one such difference tips a cell to another glyph, and a snapshot
recorded on one platform fails on the other. `tests/suite/portable_maths.rs` holds the rule.
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
- `install-hooks` leaves another tool's hook alone, except git-lfs's own
  (recognised by its shape, as its wording changes between versions): fun-ci
  writes a hook that runs fun-ci's and then git-lfs's, keeping a push's ref
  list in a file so both read it. `check` warns of a post-commit or pre-push
  hook that doesn't run fun-ci.
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

## The agent interface

Problem: an agent working in a project got a verdict only on push. The
post-commit run's output went nowhere, a failed stage's output was never kept,
and the console is made for eyes. §9 of `acceptance-tests.md` gives agents
commands that ask about commits (`lib/fun_ci/agent/`).

**Decisions:**

- **The commit is the only event.** Nothing is installed into an agent's
  harness. The post-commit hook prints the `fun-ci wait` command for the
  commit, and `init` writes one instruction into `AGENTS.md` or `CLAUDE.md`:
  run it in the background. A harness that runs background commands and wakes
  the agent when one exits needs nothing more.
- **Runs are keyed on the commit**, per project (`Persistence::ProjectRuns`
  scopes every query by `project_path`, since all projects share one
  database). A tree hash was considered and dropped: stage scripts receive the
  commit hash, so a verdict can't safely pass between commits.
- **The database lives in the user's state directory**
  (`$XDG_STATE_HOME/fun-ci`, or `~/.local/state/fun-ci`), not `$TMPDIR`,
  which a sandboxed agent can have its own of.
- **`wait` polls once a second behind a clock seam** (`Agent::Context#clock`),
  so tests script a run's progress per pause and never sleep. It gives a
  commit 5 seconds for the post-commit hook's run to turn up before starting
  one, by spawning `fun-ci trigger --background` rather than forking, so the
  run shares no SQLite connection with the waiting process. It exits 5 when
  the project can't start a run, which the pre-push hook lets through.
- **A waiter protects its run by a heartbeat**, `pipeline_runs.waited_at`,
  set on each poll; the stale canceller skips a run marked in the last 10
  seconds, and never cancels a run of the new run's own commit. A timestamp
  needs no liveness check, so the canceller sends no extra signals.
- **Evidence is kept only for failures**: the last 200 lines (64 KB) of a
  failed or over-budget stage's output, and what the extractors picked out,
  pruned to a project's 50 newest runs. How much more is kept, and how, is the
  next section.
- **`events` is the difference between two looks at the runs**, so it needs no
  events table: every event follows from the stage rows and their finish order.

## Evidence of a failed stage

Problem: an agent told a stage failed should never rerun the suite to find out
why, and the cause is often not in the last lines. Gradle and Maven print a
test's stack trace far above their summary, a build can print a hundred errors
after the first one that counts, a Rails test writes to `log/test.log`, a JSON
appender hides the exception among thousands of `debug` lines, and a stage
killed at its budget says nothing about what it was stuck on. §10 of
`acceptance-tests.md` builds `fun-ci why` over evidence picked out at the
moment a stage fails (`lib/fun_ci/evidence/`); what the agent sees is in
`design.md` (Agents).

**Decisions:**

- **Evidence is collected where the stage ran, before its outcome is
  recorded**, since the output, the stage directory, the worktree's files and
  an overrunning process group are all gone within seconds.
  `Pipeline::StageExecution` runs every stage this way, the slow suite in its
  forked child too, and `StageEnd` records the evidence, then how the stage
  exited, then the outcome.
- **Collecting never changes a verdict.** A mistaken entry, an extractor that
  raises or runs out of time, and anything else that goes wrong while
  collecting is kept as a problem, and the outcome is recorded all the same.
  `fun-ci check` reports mistakes in the `evidence` configuration; the trigger
  never reads them.
- **The output is a window on disk**: its first 1 MB and last 7 MB, cut on line
  ends, with a line saying how much was dropped. `OutputWindow` writes it as it
  comes, the tail in two segments that take turns, so neither memory nor disk
  grows with what a stage prints. It lives in a directory per stage
  (`Pipeline::StageDir`, which also holds a project extractor's scratch) in the state
  directory, because it is unmasked until the stage is recorded; the state
  directory is made 0700, and a stage directory whose process died is removed
  when the next stage starts.
- **Everything kept is masked first**: the values of the stage's secret-named
  variables (the environment is given as a hash, never read from `ENV`), the
  shapes of well-known tokens, and a project's own `mask` patterns. Masking is
  a best effort, which is why the state directory is its user's alone.
- **The evidence is one JSON document per stage** (`stage_jobs.evidence`): the
  extractors chosen and why, facts, failures, excerpts and problems, capped at
  256 KB because `why` prints it whole into an agent's context
  (`Evidence::Caps`). Nothing the stage row already holds is repeated in it,
  so nothing stored goes stale; the row gained `exit_status`, `signal` and
  `budget`. The `output_tail` and `failures` columns are still written, for an
  older fun-ci sharing the database.
- **The raw output is a gzip file per stage beside the database**, kept for a
  project's 10 newest runs, because SQLite doesn't give a deleted blob's space
  back without a `VACUUM` and one database serves every project. It is there
  for when the extractors chose wrong. `Persistence::Retention` prunes it with
  the evidence (50 runs), and removes any whose stage row is gone.
- **Built-in extractors are Ruby classes; a project's own is a command.** The
  built-ins (`grep`, `section`, `log-file`, `json-log`, `junit-files`,
  `process-tree`, plus `output-tail`, which always runs)
  declare the options they take, which is how `check` validates an entry. A
  project's extractor (`run:`) gets the context as JSON on stdin and prints
  text or JSON, both pinned in `contract/evidence/`. So it can be written in
  the project's own language, is killed with everything it started when the
  budget runs out, and can't crash the trigger or inherit its SQLite
  connection. The cost is a process per extractor, and on macOS the first run
  of a freshly written executable is scanned, which under load has taken past
  the budget (Gotchas in `CLAUDE.md`).
- **Test reports are read where the build writes them** (`junit-files`),
  because Surefire and Gradle write one JUnit file per class and a slot keeps
  the ones earlier runs wrote: a report whose stamp hasn't changed since the
  stage started is an earlier run's and is left out. Until 2.0.0, stages copied
  reports into a directory of their own (`FUN_CI_REPORT`); a copy took the
  earlier runs' reports along, so a renamed test's old failure, or the last
  run's failures after a build that broke before the tests, read as this run's.
- **Presets are data, one YAML file each** (`lib/fun_ci/evidence/presets/`),
  in the shape of an entry a project would write, so adding a stack adds a
  file. None ships without the recorded output of a real failing run of its
  tool, made in a pinned Docker image by `script/record_evidence_fixture.rb`
  and kept in `test/fixtures/evidence/`.
- **Presets choose themselves.** A preset is a candidate when the worktree has
  one of its marker files, checked when the stage starts at its commit, and
  runs when its signature, a line only its tool prints, is in the output's last
  megabyte. `script/bench_detection.rb` measured about 0.04 s per signature
  over a full window, 1.6 s with all 34 presets candidates and joining the
  patterns saving nothing, and 0.2 s over the last megabyte, where tools print
  their summaries. `init` writes no lists, which would go stale when a project
  adds a tool.
- **Evidence has a budget**, 2 seconds by default (`evidence.budget`), shared by
  the configured entries and the detected presets. Built-ins run in fun-ci's
  own process and can't be killed, so they check the deadline every thousand
  lines, and every pattern is compiled with a timeout of its own rather than
  the process-wide `Regexp.timeout`, since stages run in threads side by side.
- **An overrun is looked at before the kill**, with 2 seconds of grace:
  `process-tree` names the deepest process of the stage's group still running,
  and `on: overrun` entries get the group as `FUN_CI_PGID`, for a thread dump
  or `py-spy dump`. The hook rides on `ProcessRunner::Launch`. `ps` is read in
  its BSD and procps form, and busybox's, which takes neither `-A` nor `=`.

*Revisit if* a tool prints its only signature early in an output longer than a
megabyte (then scan the window's head too); if Ruby projects ask for in-process
extractors often enough to be worth a second mechanism (then run them in a
child Ruby); or if a common stack needs longer than 2 seconds to dump its state
before the kill.

## Checking against the trunk

Problem: fun-ci said whether a commit was fine on its own, never whether it
would still be fine merged with everyone else's work. §11 of
`acceptance-tests.md` checks each run's commit against the trunk
(`lib/fun_ci/trunk/`); what the developer and agents see is in `design.md`
(The trunk).

**Decisions:**

- **A check is a fact about the run's commit, not a stage.** A fifth stage
  would put a pass or fail into the run's status and the verdict, so a
  conflict someone else caused would fail the run and break the streak.
  *Revisit if* teams ask to hold commits to "integrates cleanly" as strictly
  as to the fast suite; then `--trunk` becomes a level of `--need`.
- **Checks are rows written once per commit and trunk SHA**
  (`trunk_checks`). A check never goes stale for its pair, only when the
  trunk moves, so a new SHA makes a new row, and two processes checking the
  same pair write the same row once. What is shown (`in trunk`, `up to date`,
  `checking`, stale) is derived when read, never stored.
- **`git merge-tree --write-tree`, in memory, in a scratch object
  directory.** It needs no worktree slot, took about 10 ms here, and with
  `GIT_OBJECT_DIRECTORY` pointed at a scratch directory that borrows the
  repository's objects, leaves nothing behind (it writes the merged tree and
  conflicted blobs otherwise). It runs through `ProcessRunner`, held to 5 s
  and killed with its process group past that.
- **A merge of the tips, not a replay of each commit.** A rebase can stop on
  an intermediate commit where the merge is clean, and the reverse;
  `git replay` would do it in memory but is marked experimental.
  *Revisit if* developers hit rebase conflicts the check called clean.
- **fun-ci fetches the trunk into `refs/fun-ci/trunk/<remote>/<branch>`,
  with an empty refmap**, since without `--refmap=` git moves
  `refs/remotes/<remote>/<branch>` too, which would change what `git status`
  says and race the developer's own fetch for the ref's lock. Nothing may
  prompt: batch-mode ssh (unless the developer has an ssh command of their
  own), no askpass, a 20 s deadline. The interval is claimed in one SQL
  statement, doubling after failures up to an hour.
- **Only the main thread touches the database.** The trigger begins the check
  before the stages (resolving the trunk, claiming the fetch, starting it
  behind `ProcessRunner`'s gate so its group is recorded for a cancel),
  finishes it in a thread (waiting for the fetch, merging, checking the other
  branches' newest runs when the tip moved), and records it after the stages
  through whichever recorder it holds then, since the slow suite's fork
  closes the one it started with.
- **The notice of a first fetch is worked out before the fork**, by
  `PipelineForker`, because the post-commit hook's run is in the background
  and what it prints goes nowhere.
- **Reading never checks.** `status`, `runs`, `events` and the console read
  the recorded checks and say when the trunk has moved since; only `--trunk`
  checks again, and never fetches, so a command an agent runs never waits on
  the network.
- **The console's marker belongs to the branch.** Ruby sends it on a
  branch's newest run from the branch's latest settled check, and sends
  `trunk_conflict` and `trunk_clear` at most once a poll; the renderer
  decides nothing about which rows qualify.

*Revisit if* the trunk moves often while nobody commits, leaving the board
stale; a console timer that fetches and checks would fix that, and would be
the console's first git call.

## Daily and weekly jobs

Problem: some checks take longer than the time between commits, and a stage's
budget exists to keep feedback fast. §13 of `acceptance-tests.md` runs them as
jobs (`lib/fun_ci/jobs/`); what the developer sees is in `design.md` (Daily and
weekly jobs).

**Decisions:**

- **Commits start jobs; there is no scheduler.** fun-ci has no daemon, and a
  launchd or cron entry would be one more thing to install per platform. The
  post-commit hook's `trigger --background` starts the committing project's
  due jobs, so the hooks people already installed start them. A project nobody
  commits to runs none. *Revisit if* people want checks on projects they no
  longer touch.
- **Due is read from the latest run alone**: none, cancelled, or started a
  period (24 h, 7 days) ago. A cancelled run doesn't count as a run, so
  cancelling is how a developer asks for another.
- **The lock decides who starts a job, the database records it.** Each job
  has a lock file beside its worktree (`<git-common-dir>/fun-ci/jobs/<name>.lock`),
  held for the whole run. A process starts a job only once it holds the lock
  (non-blocking; one that can't, leaves), and then claims the run with one
  `INSERT ... WHERE` that checks it is due. Holding the lock also proves a
  `running` row of that job is dead, so it is recorded failed before the claim.
  The trigger reads which jobs are due before forking, so a commit forks
  nothing when none is; the child, under the lock, decides.
- **A job is a process of its own, forked and detached from the trigger**,
  like the slow suite, since the trigger exits when its pipeline ends. It
  forks before the pipeline opens its recorder, and opens its own connection.
- **A worktree per job**, under `fun-ci/jobs/`, never a pipeline slot: a job
  can take hours, and a pool of two would be one for hours.
- **One budget, 24 hours, for daily and weekly jobs**, enforced by
  `ProcessRunner` like a stage's. A newer commit's run cancels pipelines only.
- **Rows in `job_runs`, apart from `pipeline_runs`**, so no query about runs
  (the board, the streak, the agent commands) can see a job. A job runs through
  the same `StageExecution` as a stage, with a recorder of its own, so its
  evidence is collected the same way; its raw output is kept beside the
  stages' under `raw-jobs/`, whose ids are its own.
- **Ruby decides the job section, the renderer draws it.** `board` carries
  `jobs` in the order shown, each with its words' facts (status, commit,
  branch, times, when due); the cursor indexes runs, then jobs.

## Quality standards (from intent-record)

- `rake` (default) is the gate: the Ruby tests, the Rust tests, the binary
  contract, RuboCop and Clippy; CLAUDE.md lists the lanes and a test holds the
  list. The mutation lanes (`rake mutation`, `rake mutation:rust`) run in CI
  nightly, each only when a file it depends on changed since its last
  finished run (`.github/workflows/mutation.yml`), since they take hours and
  commits come more often than that. The mutants in a commit's own lines run
  in the slow stage of this repository's own fun-ci pipeline.
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

## Polishing the console with agents

Planned in §6 of the acceptance tests. There is no loop runner: polishing is
something one agent does in an ordinary session, following a guide that
suggests how to work in passes. The guide is a project skill,
`.claude/skills/polish-console/`, so it loads only when an agent is asked to
polish, rather than into every session.

One pass renders the scenarios headless, evaluates them against the rubric,
takes the finding with the most impact, tries candidate fixes for it, keeps
the best one or none, and commits. The agent runs passes until no open finding
is above the rubric's threshold, or it reaches the number of passes it was
given, and then hands the snapshot changes to a human.

**Decision: a fresh subagent evaluates each pass.** An agent that has just
changed a scene knows what it meant the change to do, and tends to see it done.
So where the harness has subagents, the guide has the agent delegate each
pass's evaluation to a new one, which gets the renders, `stats.json` and the
rubric, and neither the diff nor the code, and which never edits. Where there
are none, the agent evaluates at the start of the pass, before it opens any
scene code. Candidate fixes can be delegated too, one subagent per candidate
value, each in a worktree of its own, so a sweep is rendered side by side.
*Revisit if* evaluations by the agent itself turn out to agree with fresh
ones, which would make the delegation cost with nothing to show for it.

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
- **The fix** takes the highest-impact finding and tunes like a sweep:
  name the parameters in the scene's code that bear on it, change one at a
  time, compare labelled candidates, and mark the finding `needs-design` when
  no parameter can fix it because a mechanism is missing.
- **A human approves** every snapshot change after watching it in a real
  terminal, since headless output can't show how the terminal's font and
  repaint behave. An agent can propose aesthetics; it can't approve its own.
