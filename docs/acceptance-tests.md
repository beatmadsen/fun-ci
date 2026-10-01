# fun-ci acceptance tests

The requirements, as acceptance tests, numbered like agent-tome's. They are
built one at a time, in the order of their numbers, and each is committed with
its number at the start of the subject, so `git log --grep 'AT-10\.'` shows
which of a section are built. §6 is still to build; the built sections stay
here because the tests that hold them cite them by number. An
outline item is refined into full Given/When/Then before it is built, as its
own commit to this file. What fun-ci is for is in [`design.md`](design.md).

Where a test says "the gate", it means `bundle exec rake` (default task).

---

## 0. Quality baseline (intent-record standards)

### 0.1 RuboCop is part of the gate with the project's limits
**Given** `.rubocop.yml` with `Metrics/MethodLength: 7`, `Metrics/BlockNesting: 2 (CountBlocks: true)`, `Metrics/ParameterLists: 4`, `TargetRubyVersion: 3.2`, `NewCops: enable`
**When** the gate runs
**Then** rubocop runs after the tests and the gate fails on any offence.
**And** when AT-0.1 is done, `.rubocop_todo.yml` names only files under
`lib/fun_ci/tui/` and `lib/fun_ci/animations/`, and a test fails if it names
anything else.
*Bites:* a commit shows a deliberate 8-line method failing the gate, then reverted.
*Note:* existing offences are fixed, not excluded. The gate lands first
(AT-0.1.0) with a generated `.rubocop_todo.yml` listing every existing offence
by file, so the gate is green and measuring from the first commit. Each later
AT-0.1.x commit fixes one area and deletes its entries: `lib/fun_ci/setup/`,
`persistence/`, `pipeline/`, the top-level `lib/` files and `exe/`, then
`test/unit/`, `test/acceptance/`, `test/integration/`, `features/`,
`contract/` and the root files. Most method-length offences are in the tests,
and the 7-line limit applies to test code too. `tui/` and `animations/` keep
their entries: §3.6 turns the animations into JSON and §5 deletes both.

### 0.2 Constructor parameter objects replace long keyword lists
**Given** `Trigger.new` takes 10 keyword arguments
**When** ParameterLists (4, keywords counted) is enforced
**Then** collaborators are grouped (`Trigger.new(project:, commit:, io:, seams:)`), and every existing DI seam listed in CLAUDE.md is still injectable.
**And** `Trigger` and `StageRunner` meet every limit: at most 4 instance variables,
4 parameters, 7-line methods and 150-line files (`trigger.rb` is 158 lines with 10
instance variables today).
**And** the files listed in `AWAITING_AT_0_2` in `test/unit/test_rubocop_todo.rb`
(the two classes plus the tests that construct them) have no entries left in
`.rubocop_todo.yml`, and that list is deleted.
*Note:* AT-0.1 left these files alone on purpose. Their offences come from the
constructors this item redesigns, and fixing the tests twice would be waste.

### 0.3 The cucumber lane and every documented lane run in the gate
**Given** `rake -T` lists lanes
**When** the gate runs
**Then** every lane that CLAUDE.md or README documents as a way to run the suite runs in `rake default`, and a test asserts the default task's prerequisites match the documented list.

### 0.4 Tests are confined to temp directories
**Given** the test helper
**When** any test opens a SQLite database, writes a file, or runs git outside `Dir.tmpdir`
**Then** that test fails with a message naming the path. A meta-test fails the suite if the guard is not installed.

### 0.5 Unit and acceptance tests never spawn processes
**Given** `test/unit/**` and `test/acceptance/**`
**When** a meta-test parses them (Prism)
**Then** any call to `spawn`, `fork`, `system`, backticks, `Open3.*`, `IO.popen` or `Process.spawn` fails the suite, naming file and line. `test/integration/**` is exempt.
*Note:* existing acceptance tests that spawn move to `test/integration/`.

### 0.6 Mutation testing lane
**Given** `.mutineer.yml` with `threshold: 90`, `jobs: 4`, `framework: minitest`
**When** `rake mutation` runs (Ruby ≥ 3.4 only; mutineer is not loaded on older Rubies)
**Then** it fails below 90. `rake mutation:changed` mutates only files changed since `HEAD`.
*Bites:* shown once with `threshold: 99`.

### 0.7 CI runs the gate on every supported Ruby
**Given** `.github/workflows/ci.yml`
**Then** it runs `bundle exec rake` on push to main and PRs across Ruby 3.2, 3.3, 3.4, 4.0 with `fail-fast: false`, plus `rake mutation` on 3.4.
*Note:* since 2.0.0 the mutation lanes run nightly (`mutation.yml`), each only
when a file it depends on changed since the last finished run: they take
hours, and commits come more often.

### 0.8 The gem ships exactly the tracked runtime files
**Given** the gemspec
**Then** `spec.files` is the files git tracks under `lib/` and `exe/`, plus README, CHANGELOG and LICENSE, and a test asserts nothing else is in it.

### 0.9 CLAUDE.md is written as Invariants and Gotchas
**Then** CLAUDE.md has sections Stack, Layout, Invariants, Gotchas; every invariant names the test that enforces it, and a test fails if a named test file doesn't exist.

### 0.10 Legacy executables are gone
**When** the gem is built
**Then** it ships only `exe/fun-ci`; `fun-ci-trigger` and `fun-ci-tui` are removed and the CHANGELOG lists this under Unreleased → Removed.

---

## 1. Worktree isolation per commit

All tests here are integration tests against a real temporary git repository.

### 1.1 A pipeline runs in a worktree at the requested commit
**Given** a repo with `.fun-ci/` scripts that write `$(pwd)` and `$(git rev-parse HEAD)` to a file outside the repo
**When** `fun-ci trigger <sha> main` runs
**Then** every stage ran in a directory under `<git-common-dir>/fun-ci/worktrees/`, at exactly `<sha>`, not in the main checkout.

### 1.2 Uncommitted changes don't leak into a run
**Given** a committed file and an uncommitted edit to it in the main checkout
**When** a pipeline runs for HEAD
**Then** the stage scripts see the committed content.

### 1.3 Ignored caches survive between runs in the same slot
**Given** a stage that creates `vendor/cache/marker` (ignored by `.gitignore`)
**When** two pipelines run one after the other
**Then** the second run's worktree still has `vendor/cache/marker`; untracked non-ignored files from the first run are gone.

### 1.4 The slot stays taken until the background slow suite finishes
**Given** a pool size of 1 and a pipeline whose slow suite is still running (controlled by the test via the injected background launcher)
**When** a second pipeline starts
**Then** it waits for a free slot rather than sharing the worktree, and the recorder marks it `pending` until then.

### 1.5 Crashed runs don't leak slots
**Given** a slot lock naming a pid that no longer exists
**When** a pipeline needs a slot
**Then** the stale slot is reclaimed.

### 1.6 Cancelling a stale run frees its slot
**Given** a running pipeline on `main` holding a slot
**When** a newer commit on `main` triggers a pipeline and `StalePipelineCanceller` cancels the old one
**Then** the old run's process group is killed and its slot is released.

### 1.7 Pool size is configurable
**Given** `.fun-ci/config` with `worktree_slots: 3`
**Then** at most three runs execute concurrently; default is 2.

### 1.8 The background hook is post-commit and records the new commit
**When** `fun-ci install-hooks` runs
**Then** a `post-commit` hook calls `fun-ci trigger --background <sha> <branch>` with the SHA of the commit just made; no `pre-commit` hook is written.

### 1.9 Upgrading replaces fun-ci's own pre-commit hook only
**Given** a pre-commit hook written by fun-ci 1.x, and separately a user's own pre-commit hook
**When** `fun-ci install-hooks` runs
**Then** fun-ci's 1.x hook is removed; a user's hook is left alone, and when it still calls fun-ci, `fun-ci check` warns that fun-ci now runs after the commit (the warning doesn't fail the check).

### 1.10 `--no-validate` keeps working as an alias for one release
**When** `fun-ci trigger --no-validate <sha> <branch>` runs
**Then** it behaves like `--background` and prints a one-line deprecation notice to stderr.

### 1.11 Worktrees are cleaned up with `fun-ci prune`
**When** `fun-ci prune` runs with no pipeline active
**Then** all fun-ci worktrees and their admin entries (`git worktree prune`) are removed.

### 1.12 Cancelling from the console stops the run
**Given** a running pipeline, in its foreground stages or its background slow
suite, and the console with the cursor on it
**When** the user presses `c`, then `y`
**Then** the run's process group is killed, stage scripts included, the run is
recorded `cancelled`, and its worktree slot is released.
**And** `features/admin_tui/cancellation.feature` asserts the kill again, in
place of today's "the running pipeline should be recorded as cancelled".
*Note:* 1.x records `cancelled` and stops nothing (found when the cucumber
steps were made to check what they say). It stores a pid only for the slow
suite's forked child, and each stage script runs in a process group of its
own, so killing that pid would leave `slow.sh` running. `StalePipelineCanceller`
has the same hole, which AT-1.6 closes. Both need the process group of the
whole pipeline recorded per run.

---

## 2. Protocol and golden corpus (still Ruby-only)

### 2.1 ConsoleSession separates state from rendering
**Given** a `ConsoleSession` built with `BoardData`, `KeyHandler`, a renderer port and a clock
**When** it receives `key j`
**Then** it moves the cursor and sends a new `board` message to the port. No ANSI is produced by `ConsoleSession`.

### 2.2 `board` messages follow the protocol
**Given** the fixtures in `contract/fixtures/*.jsonl`
**When** `ConsoleSession` is replayed against the renderer→Ruby lines of each fixture
**Then** it emits exactly the fixture's Ruby→renderer lines (JSON-equal).

### 2.3 Stage changes become events, not animations
**Given** a board where stage `fast` goes from `running` to `failed`
**Then** `ConsoleSession` sends `event stage_failed` with `run_id` and `stage`, followed by the new `board`.

### 2.4 Resize changes the page size
**When** the port reports `resize rows:40`
**Then** the next `board` carries as many runs as fit (header height and footer accounted for) and `has_more` is correct.

### 2.5 Protocol errors never crash the console
**When** the renderer sends a malformed line or an `error` message
**Then** Ruby logs it to `.fun-ci/console.log` and carries on.

### 2.6 Scenarios capture the current Ruby renderer as golden output
**Given** eight scenarios in `contract/scenarios/<name>.jsonl`, written in the
headless scenario format of `renderer-protocol.md` (`empty`, `happy-7`, `running`,
`fail-explosion`, `success-fireworks`, `narrow-60`, `wide-200`,
`resize-mid-animation`), which between them use every run and stage status
**When** `rake contract:capture` runs
**Then** it writes `contract/golden/<name>/NNNN.bytes`, one file per `tick`, holding
exactly the bytes today's Ruby renderer writes for that frame when wired as
`fun-ci console` wires it (animated header, `AnimationRenderer`, live height),
with the scenario's clock in place of `Time.now`
**And** running it again in a new process produces identical files
**And** a test in the gate fails when the Ruby renderer's output no longer matches
the golden files, so §0 refactors of `tui/` can't change what users see unnoticed.
*Bites:* a deliberate change to the footer text fails the gate, then reverted.
*Note:* the project name colour came from `String#hash`, which Ruby seeds per
process, so it changed on every console start. It is fixed to a CRC-32 of the
name before capture; otherwise neither a byte-identical golden nor Rust parity
is possible.

---

## 3. Rust renderer to parity (outline)

- 3.1 `renderer/` Cargo crate `fun-ci-renderer`; `rake` runs `cargo test` and `cargo clippy -D warnings` with the thresholds from architecture.md. Bites shown.
- 3.2 Handshake: `hello v1` → `ready`; unknown version → `error version`, exit 2.
- 3.3 Headless mode writes `frames.jsonl`, `frames/NNNN.png`, `sheet.png`, `frames.cast`, `stats.json` (fields in `renderer-protocol.md`). The PNGs decode at the expected pixel size for the grid and font.
- 3.4 Differential tests: for every scenario, the `vt100` cell grid of the Rust output equals that of `contract/golden/<scenario>.bytes`, frame by frame.
- 3.5 Contract fixtures: the Rust suite accepts every fixture's Ruby→renderer lines and emits its renderer→Ruby lines.
- 3.6 Animations load from `renderer/animations/*.json` (converted from the Ruby modules by a one-off script, checked in). Superseded after 2.0.0: the header's animations are scenes in code (architecture.md, "Animations as scenes").
- 3.7 Terminal is restored on EOF, `quit`, panic and SIGTERM.
- 3.7b The cancel prompt names the run's branch and short SHA (`Cancel feat/search (d4e5f67)? y / n`), as the original feature spec asked. The 1.x prompt is generic, and the renderer has what it needs from `cursor` and `runs`.
- 3.8 `rake contract:binary`: Ruby drives the real binary through a pty for the `happy-7` fixture. In the gate.
- 3.9 cargo-mutants lane ≥ 90 % caught.

## 4. Distribution (outline)

- 4.1 Renderer lookup (`Console::RendererLookup`): `FUN_CI_RENDERER` → bundled `libexec/` → `PATH` (empty entries skipped, never the current directory); a named renderer that cannot run is an error, not a fallback; with none found, the error says how to get one (`cargo install fun-ci-renderer`, or `FUN_CI_RENDERER`). `fun-ci console` uses it from 5.1, whose tests show that a missing renderer fails only `console`.
- 4.2 Platform gems for the five targets built in CI; each installed into an empty `GEM_HOME` and smoke-tested headless.
- 4.3 `cargo install fun-ci-renderer` path documented (`renderer/README.md`, the crate's page) and tested in CI short of publishing: `cargo publish --dry-run` packages and builds the crate as crates.io would take it, and a renderer installed with `cargo install --path renderer` is the one the plain gem finds on `PATH` and runs. Publishing the crate and the gems is a release decision, not a test.

## 5. Cut-over (outline)

- 5.1 `fun-ci console` uses the Rust renderer, found by `RendererLookup`, and the README says how to get one where the gem does not bundle it (`cargo install fun-ci-renderer`, `FUN_CI_RENDERER`); without one, `console` exits non-zero with the lookup's instructions and every other command works as before.
- 5.2 Golden byte files become Rust `insta` snapshots; `contract:capture` is removed.
- 5.3 Cucumber TUI features are rewritten against headless frames or deleted where the Rust suite covers them.
- 5.3b Ruby `tui/` rendering classes and `animations/` are deleted, once 5.2 and 5.3 leave nothing that drives them (the golden corpus capture and the Cucumber features do until then).
- 5.4 README, CHANGELOG, version 2.0.0.

## 6. Polishing the console (outline; see architecture.md, "Polishing the console with agents")

- 6.1 Objective visual gates from `stats.json` and `frames/` in `rake`, including "consecutive animation frames differ" and "every PNG decodes at the expected size". Bites shown for each.
- 6.2 `docs/tui-rubric.md`, derived from `design.md` and separating state feedback from decoration, with a threshold for a finding worth a pass, and optional reference screenshots in `docs/tui-references/`.
- 6.3 The `polish-console` project skill: how one agent works in passes (render, evaluate, fix one finding, commit) until no finding is above the threshold or its passes run out, and hands the snapshot changes to a human.
- 6.4 Evaluation in the skill: a fresh subagent each pass where the harness has them, else the agent's own evaluation before it reads scene code; reads ordered PNG frames (never a GIF), the contact sheet, `stats.json` and the rubric, never the diff; every finding names a scenario and a frame range or region.
- 6.5 Fixing in the skill: one-parameter sweeps rendered as labelled candidates, optionally one subagent and worktree per candidate; edits limited to the values the finding concerns; `needs-design` when no parameter can fix it.
- 6.6 `rake polish:approve`, run by a human after viewing the change in a real terminal.

## 7. Glanceable milestones

The header's animations carry fun-ci's first goal, all is well at a glance,
and its second, fun (`design.md`, Goals and Animations). A run's milestones are
`lint passed`, `build passed`, `fast passed` and `passed` (the slow suite
passed as well), or `failed`. Lint and build run in parallel, so their
milestones come in either order; the rest come in the order listed. This
section replaces the rule under which a failure cut a celebration short.

### 7.1 A run's status is worked out from its stages, in any order
**Given** a run whose stages finish in any order, including the forked slow
suite finishing before or after the fast suite
**Then** the run's status follows from its stages' statuses alone: `failed`
once any stage has failed or timed out; `completed` once lint, build, fast and
slow have all passed; otherwise `running`
**And** `failed` and `cancelled` are final: nothing written later changes them
**And** the status is written in one statement that reads the stage rows, so
the foreground pipeline and the slow suite's process cannot overwrite each
other's verdict.
*Bites:* fast fails, then slow passes. Today the run ends `completed` and the
console shows it PASSED. The test goes red on today's code for that reason.
*Note:* the console, the streak counter, cancelling and the stale-run canceller
all read this status, so none of them needs changing. A slow suite that passes
while fast is still running no longer shows the run as passed for a moment.

### 7.2 Each milestone becomes one event, in the order it was reached
**Given** two polls of the runs
**When** a run has reached milestones between them
**Then** Ruby sends one event per new milestone, `lint_passed`, `build_passed`,
`fast_passed`, `run_passed` or `run_failed`, each with `run_id`, in the order
the milestones were reached: lint and build in the order their stages
finished, which is recorded as each stage ends, not read off timestamps
(which tie within a second), fast before `run_passed`, and any milestones reached
before a failure ahead of `run_failed`
**And** a run sends `run_failed` once, however many of its stages fail
**And** a cancelled run sends nothing, and the first poll after the console
starts sends nothing (there is no earlier poll to compare with)
**And** `stage_passed` and `stage_failed` keep coming as they do now; they drive
the effects on a stage's column, which show *which* stage failed, while the new
events drive the header
**And** `renderer-protocol.md` lists the new names.
*Bites:* a board where lint passes and build fails in the same poll sends
`lint_passed` then `run_failed`; a second board where fast also shows failed
sends no second `run_failed`.

### 7.3 Every milestone has its own pool of scenes
**Given** the scene library
**Then** each of `lint passed`, `build passed`, `fast passed`, `passed` and
`failed` has a pool of scenes, and the renderer picks from the event's pool at
random
**And** the success pools share no scene, so a scene tells the viewer which
milestone it stands for
**And** every success pool has at least two scenes
**And** the scenes grow along the path: lint's and build's are the smallest,
fast's are bigger, and the run's `passed` scenes are the biggest
**And** each can be told apart from the corner of the eye by motion, size and
colour, never by its lettering alone, and never by red against green alone
(about one man in twelve can't tell them apart well)
**And** failure moves differently from every success (a shake or a flash
against a calm rise), so "look closer" reads even when the colour doesn't.
*Note:* which scene goes into which pool, and the new scenes the pools need,
are decided by looking at rendered frames, not in this file. A scenario per
pool pins its scenes in the snapshots.

### 7.4 Header scenes queue and each plays to its end
**Given** events that call for header scenes, arriving faster than the scenes
play
**Then** the renderer queues them and plays each one to its end, in the order
the events arrived, whichever run they belong to
**And** no scene cuts another short: the priority that let a failure take over
from a success goes
**And** the looping `running` scene plays only while the queue is empty and a
run is running.
*Bites:* a scenario whose board brings `lint_passed`, `build_passed` and
`fast_passed` in one poll draws the three scenes in that order, each for its
full length, in the headless frames.

### 7.5 The header rests on the latest outcome
**Given** the queue is empty and no run is running
**Then** the header holds a resting scene for the most recent run that finished
`passed` or `failed` (cancelled runs are skipped): a calm one for `passed`, and
for `failed` one that keeps a warning in view, so a glance a minute after the
scenes played still tells the viewer how it went
**And** it holds until the next run starts, when the `running` scene takes over
**And** with no finished run to show, the header shows the idle night scene as
it does now.
*Bites:* a scenario ending on a failed run shows the failed resting scene in
its last frames; the same scenario ending on a passed run shows the calm one.

### 7.6 The streak is on the screen
**Given** consecutive passed runs
**Then** the console shows the streak, as the 1.x header did ("7 in a row!"),
and says the streak is broken after a failure, without alarm
**And** a running run neither breaks nor extends it.
*Note:* Ruby sends `streak` with every `board`, but nothing has drawn it since
the header became a picture. Where it sits in a painted header is decided by
looking at rendered frames.

### 7.7 The header goes quiet when nothing has run for a while
**Given** the latest run that passed or failed finished five minutes ago or
more, or no run has finished at all, and none is running
**Then** the header shows a quiet scene instead of the calm or warning
resting scene: one picked at random from the quiet pool (the starry night and
others as calm as it), and every five minutes it shows, another from the pool
takes over, until a run starts
**And** over the quiet scene sits a small lamp showing how the latest run
ended: steady green after a pass, flickering slowly red after a failure, and
no lamp when no run has finished
**And** the five minutes count from the run's last status change, on the
renderer's clock, so a console opened long after a run goes quiet at once.
*Bites:* a board whose run finished 299 s ago rests on the calm scene; at
300 s it shows a quiet scene; five minutes later, a different quiet scene.
*Note:* the quiet state means "nothing has happened for a while", and the
lamp keeps the answer to "was the last one fine?" in view without a scene of
its own.

## 8. Failure modes the 1.x specification promised

### 8.1 A failed stage names the next step
**Given** a stage script that fails
**When** `fun-ci trigger` runs
**Then** after the script's output and `<Stage> failed.` comes one line saying
what to do next: fix what the linter reported (lint), fix the build errors
(build), or fix the failing tests (fast, slow), then try again.
*Bites:* the line is missing today.

### 8.2 A busy database doesn't stop the pipeline, and says so
**Given** a database that stays locked past its busy timeout while a pipeline
records its stages
**When** `fun-ci trigger` runs
**Then** every stage still runs and the exit code is the pipeline's own
**And** fun-ci says once that the result could not be recorded, and that
triggering again will record it.
*Bites:* today the busy error ends the trigger.

### 8.3 A slow suite that dies is recorded failed
**Given** a run whose slow stage is `running` and whose forked slow-suite
process no longer exists
**When** the console next polls
**Then** the slow stage is recorded `failed`, and the run with it (AT-7.1),
so the console shows it failed instead of running.
**And** a slow stage whose process is still alive is left running.
*Note:* the check is on the forked process, not the slot lock: the slot is
released just before the slow suite's result is recorded, and a lock check
would fail a run that passed in that moment.

### 8.4 An unwritable database is reported with its path
**Given** a database that cannot be written (a full disk, a read-only file)
while a pipeline records its stages
**When** `fun-ci trigger` runs
**Then** every stage still runs and the exit code is the pipeline's own
**And** fun-ci says once that it can't write to the database, names its path,
and suggests checking the disk.

## 9. An interface for agents

An agent working in a project asks fun-ci about commits and branches on exit
codes. The commit is the only event: fun-ci tests commits, speaks up after one,
and never looks at uncommitted files. Every command below runs in the project
directory, names a commit with anything `git rev-parse` accepts (`HEAD` by
default), and takes `--json`. Why they look as they do is in `design.md`
(Agents) and `architecture.md` (The agent interface); `fun-ci why` is §10.

Exit codes, shared by `status` and `wait`: 0 passed (every stage the agent
needs passed), 1 failed, 2 over budget (a needed stage ran out of time),
3 undecided (still running), 4 superseded (a newer commit on the branch
replaced the run), 5 unknown (no run for the commit), 64 usage error. The
level an agent needs is `--need build` (lint and build), `fast` (the
default: lint, build and the fast suite) or `all` (the slow suite too).

### 9.1 The database lives in a per-user state directory
**Given** `XDG_STATE_HOME` set, or not
**When** any fun-ci command opens the database
**Then** it is `$XDG_STATE_HOME/fun-ci/db.sqlite3`, or
`~/.local/state/fun-ci/db.sqlite3` without it, whatever `TMPDIR` is.
*Bites:* today it is under `$TMPDIR`, which a sandboxed agent can have its own
of, so its runs never reach the console.

### 9.2 `fun-ci status` says where a commit's run stands
**Given** a project with a run for a commit
**When** `fun-ci status [REV] [--need LEVEL]` runs in it
**Then** it prints the short SHA, subject and branch, then one line per stage
with its state and, once finished, its duration
**And** exits with the verdict for the level needed: 0, 1, 2, 3, 4 as above,
from the newest run of that commit in this project.
**And** a commit with no run in this project exits 5 and says so, and a REV git
can't resolve exits 64 and says so.
*Note:* runs are the project's own: the same SHA run in another project is not
this project's run.

### 9.3 `fun-ci status --json` gives the same facts to a program
**Given** the run of 9.2
**When** `fun-ci status --json` runs
**Then** stdout is one JSON document: `schema` 1, `commit` (`sha`, `branch`,
`subject`), `need`, `verdict` (`passed`, `failed`, `over_budget`,
`undecided`, `superseded`, `unknown`), `stages` (each `name`, `state`,
`seconds`, and `failures` when the stage reported some) and `superseded_by`
(the newer commit's SHA, or null). The exit code is the same as without
`--json`.

### 9.4 `fun-ci runs` lists the project's recent runs
**Given** a project with runs on two branches, and another project's runs
**When** `fun-ci runs [-n N] [--branch NAME] [--json]` runs in it
**Then** it prints one line per run of this project, newest first: short SHA,
branch, age, each stage's outcome, subject; at most N (10 by default), only
on NAME when given
**And** `--json` prints a JSON array of the status document of 9.3 for each.

### 9.5 A failed stage keeps the end of its output
**Given** a stage that fails, or overruns its budget, after printing more
than 200 lines, with colour codes
**When** the run finishes
**Then** the stage's last 200 lines (at most 64 KB), colour codes stripped,
are kept with it; the slow suite's too
**And** an overrun keeps what the stage printed before it was killed
**And** a passing stage keeps nothing, and a new run drops the kept output of
the project's runs older than its 50 newest.
*Bites:* today an overrun's output is discarded and the slow suite's is never
read.

### 9.6 `status` shows why a needed stage failed
**Given** a run whose fast suite failed
**When** `fun-ci status` runs
**Then** after the stage lines comes `fast failed:` and the evidence: each
reported failure (9.7) as `file:line  test` and the first 5 lines of its
message, at most 10 failures; or, with no report, the last 20 kept lines.

### 9.7 A stage's test reports name its failures
**Given** a stage that writes JUnit XML where its build keeps it, and a
`junit-files` entry for the stage naming where that is
**When** the stage fails
**Then** its failures (file, line, test, message) are kept with it and shown by
`status` (9.6) and `status --json` (9.3)
**And** a report that can't be read is ignored, and the kept output shown
instead.
*Note:* until 2.0.0 was released, stages wrote reports into a directory named
by `FUN_CI_REPORT`. It was withdrawn: `junit-files` reads the same reports and
leaves out those an earlier run left behind, which a copy took along.

### 9.8 Withdrawn: `fun-ci init` writes stage scripts that report for Gradle and Maven
The scripts copied the build's reports into `FUN_CI_REPORT`, withdrawn with it
(9.7). The Gradle and Maven presets pick the failures out of the output.

### 9.9 `fun-ci wait` waits for the level it needs
**Given** a run still going
**When** `fun-ci wait [REV] [--need LEVEL]` runs
**Then** it returns as soon as the level is decided, printing what `status`
prints, with its exit code: all needed stages passed, or the first needed
stage that failed or overran
**And** a stage the level doesn't need neither holds it up nor changes its
verdict.

### 9.10 `wait --within` gives up at the agent's deadline
**Given** a run whose needed stages are still going
**When** `fun-ci wait --within DURATION` runs (`30`, `30s`, `5m`)
**Then** after DURATION it returns 3 and prints what it knows so far.

### 9.11 `wait` starts a run for a commit that has none
**Given** a commit with no run in this project
**When** `fun-ci wait REV` runs
**Then** it starts the pipeline for that commit in the background, as the
post-commit hook does, and waits on it.
*Note:* a run recorded within 5 seconds, the post-commit hook's for a commit
just made, is waited on instead of starting another. With no run by its
deadline, `wait` says so and exits 3.

### 9.12 A run is only superseded by a newer commit nobody is waiting past
**Given** an unfinished run
**When** a pipeline starts for a newer commit on the same branch
**Then** the run is cancelled unless an agent is waiting on it, and a run for
the same commit is never cancelled
**And** `wait` on a cancelled run returns 4 and names the newer commit, and
`wait --follow-branch` moves on to the newest run on the branch and says so.
*Note:* a waiter marks the run each time it polls; a run marked in the last
10 seconds counts as waited on.

### 9.13 The pre-push hook waits for the fast verdict of what is pushed
**Given** hooks installed
**When** a push runs its pre-push hook
**Then** the hook runs `fun-ci wait SHA --need fast` for each commit git says
it is pushing, and the push stops if any is not 0
**And** a commit whose post-commit run has finished returns at once.

### 9.14 The post-commit hook says how to get the verdict
**Given** hooks installed in a project fun-ci is set up for
**When** a commit is made
**Then** its output ends with
`fun-ci: testing <sha7>. Verdict: fun-ci wait <sha7> --need all`
**And** nothing is printed when the project isn't set up and no run starts.

### 9.15 `fun-ci init` tells agents what to do after a commit
**Given** a project with `AGENTS.md`, only `CLAUDE.md`, or neither
**When** `fun-ci init` runs
**Then** `AGENTS.md` (or `CLAUDE.md` when it is the only one) gains a short
fun-ci section: after each commit, run the `fun-ci wait` command it prints, in
the background; `AGENTS.md` is created when neither exists
**And** running it again adds nothing.

### 9.16 `fun-ci events` prints what happens as JSON lines
**Given** runs of this project going
**When** `fun-ci events [--follow] [--only failures]` runs
**Then** it prints one JSON line (`schema` 1, `event`, `commit`, `branch`,
and `stage`, `state`, `seconds` for a stage) for each run started, stage
finished, run finished and run superseded: the project's last 10 runs' events,
then, with `--follow`, each new one as it happens
**And** `--only failures` prints only failed or over-budget stages and
superseded runs.

## 10. Reading why a stage failed

`fun-ci why` gives an agent everything fun-ci kept about why a stage of a
commit's run failed, so it never reruns a suite to find out. What is kept is
picked out when the stage fails by extractors: built-ins, presets for popular
stacks that fun-ci runs when they apply, and a project's own commands. Why it
is designed this way is in [`architecture.md`](architecture.md) (Evidence of a
failed stage), what an agent sees in [`design.md`](design.md) (Agents), and the
documents a project's command reads and prints in `contract/evidence/`. Each
test here pins one behaviour through a command; the cases around it belong to
the class that decides them. Exit codes are those of §9: `why` exits with the
verdict.

### 10.1 `fun-ci why` prints everything kept about a failed stage
**Given** a run whose fast suite failed, with reported failures and a kept
output tail
**When** `fun-ci why [REV] [STAGE]` runs
**Then** it prints a line naming the stage, its state, exit status, time and
budget, then each reported failure in full, then the whole kept tail (the 200
lines of AT-9.5)
**And** without STAGE it takes the first needed stage to fail or overrun, in
the order they finished, as the verdict does (`--need` as for `status`)
**And** it exits with the verdict, as `status` does.

### 10.2 `why --json` gives the same as one document
**Given** the run of 10.1
**When** `fun-ci why --json` runs
**Then** stdout is one document: `schema` 1, `commit`, `stage`,
`state` (in `status --json`'s words), `exit_status`, `signal`, `seconds`,
`budget`, `evidence` (`chosen`, `facts`, `failures`, `excerpts`, `problems`),
`no_evidence` and `raw_output`, with the same exit code
**And** for a stage that passed, `evidence` is null and `no_evidence` is
`passed`.

### 10.3 A run whose evidence was pruned says so
**Given** a failed run older than the project's 50 newest
**When** `fun-ci why` names it
**Then** it says its evidence is no longer kept and why, exits 1, and with
`--json` gives `evidence` null and `no_evidence` `pruned`.

### 10.4 The digest in `status` and `wait` names the `why` command
**Given** a run whose fast suite failed
**When** `fun-ci status` or `fun-ci wait` prints the digest of AT-9.6
**Then** its last line is `fun-ci why <sha7> fast`.

### 10.5 A secret in a failed stage's output is masked before it is kept
**Given** a stage whose environment has `DEPLOY_TOKEN=s3cr3t-value-123`, and
which prints it and fails
**When** `fun-ci why` shows its evidence
**Then** the line shows `[masked:DEPLOY_TOKEN]` where the value was, and the
value is nowhere in the database.

### 10.6 A failed stage's output is kept as a window, and `why --raw` prints it
**Given** a stage that prints more than 8 MB, then fails
**When** `fun-ci why --raw` runs
**Then** it prints the output's first 1 MB up to a line end, a marker line
saying how many bytes were dropped, and its last 7 MB from a line start
**And** `why` names the `--raw` command, since the run is one of the
project's 10 newest.

### 10.7 Every stage script knows its stage
**Given** stage scripts that print `FUN_CI_STAGE`
**When** a pipeline runs
**Then** each prints its own stage's name.

### 10.8 A stage's configured extractors run when it fails, the slow suite's too
**Given** `.fun-ci/config` with an `evidence.stages.slow` list holding a
`grep` for `ERROR`
**When** the slow suite fails printing a line with `ERROR` far above its last
200 lines
**Then** `fun-ci why` shows that line as an excerpt under `grep`, after the
reported failures and before the output tail.

### 10.9 A mistake in the configuration is reported, and only that entry is left out
**Given** `.fun-ci/config` whose fast list has a `grep` and an entry naming an
extractor that doesn't exist
**When** `fun-ci check` runs, and later the fast suite fails
**Then** `check` names the unknown extractor
**And** the failed stage's evidence has the `grep` excerpt and a problem
naming the unknown entry, and the stage's verdict is unchanged.

### 10.10 A preset picks out a tool's failures
**Given** a fast suite whose output is the recorded failing rspec run, with
its failures far above its last 200 lines
**When** its list has `use: section` with `preset: rspec`
**Then** the evidence has rspec's failures section as an excerpt under
`section:rspec`
**And** `minitest`, `gradle` and `maven` ship with their recorded runs too,
each pinned in the unit tests.

### 10.11 A log file is read from where the stage started writing
**Given** a worktree slot whose `log/test.log` holds a previous run's lines
**When** a stage appends to it and fails, and its list has `log-file` with
`path: log/test.log`
**Then** the evidence has only the lines appended during the stage.

### 10.12 The evidence says when another stage shared the worktree
**Given** a run whose slow suite was running in the slot when the fast suite
failed
**When** `fun-ci why` shows the fast suite
**Then** its facts include `alongside: slow`.

### 10.13 `json-log` keeps structured log records at or above a level
**Given** output mixing plain lines with JSON log lines at `debug`, `info`,
`warn` and `error`, one with a stack trace
**When** the list has `json-log` with `level: warn` and `preset: logstash`
**Then** the evidence has one line per `warn` and `error` record (time, level,
logger, message), each followed by its stack trace, and nothing else.

### 10.14 A failure keeps its own output
**Given** a JUnit report whose failing testcase has `<system-out>`
**When** the stage fails
**Then** `why` prints that output under the failure's message.

### 10.15 A project's own command is an extractor
**Given** `run: <command>` in a stage's list, with `format: json`
**When** the stage fails
**Then** the command gets the context document
(`contract/evidence/context.json`) on stdin, and the facts, failures and
excerpts it prints are in the evidence under its name
**And** a command still running when the budget runs out is killed with what
it started, recorded as a problem, and the verdict is unchanged.
*Note:* in the process lane, since the command is real.

### 10.16 `fun-ci extract` tries a stage's extractors on a saved output
**Given** a file holding a failing run's output, and a fast list with a `grep`
**When** `fun-ci extract fast --output FILE` runs
**Then** it prints what `why` would print for that output, the `grep` excerpt
included, and writes nothing to the database.

### 10.17 An overrun says what it was doing
**Given** a stage whose budget runs out while a child process runs
**When** fun-ci stops it
**Then** before the kill, `process-tree` records the deepest process still
running as the fact `running`, and the digest's first line is
`fast ran over budget: running <command> (<seconds>s)`
**And** a `run:` entry with `on: overrun` runs before the kill with the
stage's process group as `pgid`.

### 10.18 `why` says when only the last lines were kept
**Given** a failed stage with no reported failures and no excerpt but the
output tail
**When** `fun-ci why` runs
**Then** it ends by saying that only the output's last lines were kept and that
`evidence:` in `.fun-ci/config` adds extractors.

### 10.19 fun-ci runs the presets that apply, and only those
**Given** a project with a `Gemfile` and no `evidence` configuration, whose
fast suite fails printing rspec's rerun lines
**When** the evidence is collected
**Then** the `rspec` preset runs and `chosen` says why (`file Gemfile`,
`output matched rspec ./`), and the `gradle` preset, whose markers are
missing, does not.

### 10.20 Presets for the other popular stacks
**Given** a recorded failing run of each of these, besides the six of 10.10
and 10.13 (rspec, minitest, gradle, maven, logstash, ecs):
test runners pytest, unittest, jest, vitest, mocha, node's test runner, bun,
deno, go test, cargo test, dotnet test, phpunit, ExUnit, swift test, dart
test and GoogleTest; build, type and lint tools tsc, eslint, rubocop, ruff,
mypy, go build, rustc, gcc and shellcheck; Perl's prove; and JSON logs from
pino and structlog
**When** each is the output of a failed stage in a project with that tool's
marker files and no `evidence` configuration
**Then** its preset is chosen and picks out what its recording expects
**And** no preset's signature matches another tool's recorded run.

### 10.21 `fun-ci init` sets up every stack a preset reads
**Given** the recorded failing project of any preset of 10.10 and 10.20 but
those that read a format any stack may print (logstash, ecs, shellcheck)
**When** `fun-ci init` runs in it
**Then** it detects the preset's stack and writes that stack's four stage
scripts
**And** the stage script that runs the preset's tool, run on that project in
the recording's image, fails printing what the preset picks out.
*Note:* the stacks, first match wins: Ruby, Gradle, Maven, Rust, Go, Elixir,
Dart, Swift, PHP, .NET, Python (uv, Poetry, pip), Deno, Bun, Node (pnpm, Yarn,
npm), Perl, CMake, Make. Test stages run the fast suite without the tests the
tool's own convention marks slow, and the slow suite with only those. The
first half is a policy test in the gate; the second needs Docker and the
network, so a script checks it weekly beside the presets
(`script/check_init_templates.rb`).

---

## 11. Checking each commit against the trunk

Each run also finds how its commit stands against the team's trunk, so a
conflict with everyone else's work shows within seconds of the commit that
caused it (`design.md`, The trunk; `architecture.md`, Checking against the
trunk). A conflict is not a failure: it changes no stage, no run status, no
streak and no exit code unless an agent asks with `--trunk`. "Process" marks
the tests in `test/integration/process/`, in a temporary clone whose remote is
a bare repository in the same temp root; the rest use a fake trunk and run no git.

### 11.1 A clean merge is recorded with the commits each side lacks (process)
**Given** a branch and the remote's trunk that both moved on, on different lines
**When** the commit is checked
**Then** the check records `clean`, one ahead and one behind.
*Bites:* nothing looked at the trunk before.

### 11.2 A conflict is recorded with its files (process)
**Given** the same, on the same lines
**Then** the check records `conflicts` and the file.

### 11.3 Nothing to merge is `up to date` or `in trunk`
**Given** a check with none behind, or none ahead
**Then** it shows `up to date`, or `in trunk`.

### 11.4 A trunk with no shared history is unknown, and says what to do (process)
**Then** the reason names `trunk:` in `.fun-ci/config`.

### 11.5 A merge over its budget is stopped
**Given** a merge that runs past 5 s
**Then** it is killed with its process group and shown `unknown`, naming `trunk: none`.

### 11.6 A git that can't merge in memory is named
**Given** a git without `merge-tree --write-tree`
**Then** the check is `unknown`, naming 2.38 and the version installed.

### 11.7 The check leaves nothing in the repository (process)
**Then** `git count-objects` is unchanged and no ref outside `refs/fun-ci/` moved.

### 11.8 `trunk: none` checks nothing
**Then** no check is made and no trunk line is printed.

### 11.9 The trunk is the one configured, else the remote's, else a usual name
**Given** refs with `trunk:`, a remote's default branch, a usual name on the remote, or only local branches
**Then** the trunk is picked in that order; with none, `unknown` naming `trunk:`.

### 11.10 Real refs resolve the same way (process)
**Then** a clone's `origin/HEAD` and a local `develop` without a remote are found.

### 11.11 A run fetches the trunk into fun-ci's own ref (process)
**Given** a remote whose trunk has a commit the clone lacks
**Then** `refs/fun-ci/trunk/origin/main` is that commit, and the check reads it.

### 11.12 The fetch touches none of the developer's refs (process)
**Then** `refs/remotes/origin/main` is unchanged and there is no `FETCH_HEAD`.
*Bites:* without `--refmap=` git moves `refs/remotes/origin/main` too.

### 11.13 A second run within the interval doesn't fetch
**Then** the interval, 5 minutes by default (`trunk_fetch:`), holds it back.

### 11.14 Two runs at once fetch once
**Then** the interval is claimed in one statement, and the loser doesn't fetch.

### 11.15 `trunk_fetch: false` fetches nothing
**Then** the check reads the remote-tracking ref, as of when it last moved.

### 11.16 A fetch that fails is recorded and fails nothing (process)
**Then** its error is kept, and the stages run and are recorded as they would be.

### 11.17 A fetch that never answers is stopped at its deadline (process)
**Then** its process group is killed and `no answer within 20 s` is kept.

### 11.18 After a failed fetch the next waits longer
**Then** the interval doubles after each failure, up to an hour.

### 11.19 Cancelling a run kills its fetch
**Then** the fetch's process group is among the run's groups a cancel kills.

### 11.20 A project's first fetch is announced where it is seen
**Given** a project that fetches a remote trunk and never has
**When** the post-commit hook starts a run
**Then** after the line naming the verdict command comes what is fetched, how
often, and `trunk_fetch: false` to stop it.

### 11.21 A conflict leaves a passing run passed
**Then** the run is `completed`, and counts towards the streak.

### 11.22 A run whose lint fails still records its check

### 11.23 A check that spans the slow suite's fork is recorded once (process)
**Then** it is recorded through the recorder the run holds after the fork, and
nothing is written to stderr.

### 11.24 A check that never finished shows as unknown
**Given** a run that began a check and recorded none by the fetch deadline plus the merge budget
**Then** it shows `unknown`, "the check never finished".

### 11.25 A run that finds the trunk moved checks the other branches
**Then** each other branch's newest checked run is checked against the new tip;
a branch never checked is left alone.

### 11.26 `--trunk` checks again when the trunk has moved
**Then** `status --trunk` checks the commit against the trunk as it is now,
without fetching, and keeps the check; `status` without it says the trunk has
moved and checks nothing.

### 11.27 Two processes recording the same check keep one row

### 11.28 `status` prints the trunk line with its age, STALE past an hour or after a failed fetch

### 11.29 A conflict says when and how to integrate
**Then** the files, then a next step built from the resolved trunk: `git pull
--rebase` on the trunk branch, `git pull` elsewhere (rebase offered for an
unshared branch), `git merge` for a local trunk, and `fun-ci why <sha> trunk`.

### 11.30 A failed stage comes first
**Then** the digest precedes the trunk line, which then gives no next step.

### 11.31 A check still running prints no line without `--trunk`

### 11.32 to 11.35 `--trunk`
**Then** `status --trunk` exits 6 for a passed run that conflicts, 1 for a
failed one, the verdict alone when the trunk is unknown, and 3 while the check
runs; `wait --trunk` returns once it has finished.

### 11.36 `status --json` and `runs --json` carry the trunk object
**Then** `state`, `ref`, `sha`, `as_of`, `stale`, `fetch` (`ok`, `failed` or
`none`), `fetch_error`, `ahead`, `behind`, `files`, `reason`, `moved_to`;
`null` for a run that began no check; `schema` still 1.

### 11.37 `runs` marks a conflict before the subject

### 11.38 `why REV trunk` shows the conflicted regions
**Then** git's merge messages and each region with three lines around it,
merged again on demand; `--json` the same, capped as a stage's evidence.

### 11.39 `events` prints `trunk_checked`, and `--only failures` leaves it out

### 11.40 `init` tells agents to run `wait --need all --trunk` before calling work done

### 11.41 `check` names the trunk, why that one, and how it is fetched
**Then** with none it warns, naming `trunk:`, and exits as it would without the warning.

### 11.42 to 11.46 The board
**Then** a branch's newest run carries its standing, its latest settled check,
so a new run still checking or unknown keeps it; only a conflict is sent;
`trunk_conflict` and `trunk_clear` come at most once each a poll, keyed on
project and branch, and none for an unknown; the board names projects whose
trunk is stale.

### 11.47 A contract fixture holds the trunk conversation on both sides

### 11.48 The renderer draws the marker, the stale note and the two scenes
**Then** `conflicts with <trunk>` in lilac italics on the line under the
branch, whose marks effects still land on; the stale trunk beside its
project's name (section 12); a scene from each trunk pool and a fading
conflict banner, without changing the resting outcome, the lamp or the streak.

## 12. The quiet table

The table under the header, drawn anew after a search that built and compared
candidates five at a time (design.md, The console). The Ruby side is in
`test/integration/test_console_board_rows.rb`, the renderer's in
`renderer/tests/suite/quiet_*.rs`; the parts each rests on have tests of their
own (`test_row_order.rb`, `renderer/tests/suite/table_*.rs`).

### 12.1 One row per branch
**Given** a branch run twice **Then** the board carries only its newest run.

### 12.2 Rows in the order that needs you
**Then** a project's branches come together, the project with a failure
before one without, and the cursor walks them in that order.

### 12.3 A project's branches under its name
**Then** each project's rows sit under its name in letter-spaced capitals.

### 12.4 One block for what needs you
**Then** the cursor's row, or with no cursor the first row that needs you,
sits in one deep block, wine when its row needs you and indigo when it does
not; a board where nothing needs you has none.

### 12.5 The words leave a short name whole
**Then** on 60 columns a nine-letter branch keeps its whole name.

### 12.6 The block breathes, and a still board rests
**Then** the block lightens over two seconds; with nothing needing you, a
project's passed branches fold into one line; a board where everything passed
shows one firefly no brighter than a pale name, and a running board none.

### 12.7 A short screen keeps what needs you and counts the rest
**Then** a stale trunk is said beside its project's name; a short screen keeps
the failures and their projects' names and counts the passed rows it left
out; a screen too short for the names says the stale trunk on its own line.

### 12.8 It reads to someone who has never seen fun-ci
**Then** each row names its stage in full (`the fast suite failed after
1.4s`), briefly on a narrow screen but never in shorthand; a legend above
every project names each stage over its column of marks and says what it is
for, its lines running down to the last project; and a screen with no room
for the legend names the marks on one line above the keys
(`renderer/tests/suite/quiet_table.rs`, `table_words.rs`, `table_leaders.rs`).

## 13. Daily and weekly jobs

Checks too long for a stage's budget run as jobs, at most once a day or once a
week, started by commits (`design.md`, Daily and weekly jobs; `architecture.md`,
Daily and weekly jobs). A job is no part of a run: nothing here changes a
stage, a run status, the streak or an exit code. "Process" marks the tests in
`test/integration/process/`.

### 13.1 A script in `daily/` or `weekly/` is a job
**Given** `.fun-ci/daily/mutation.sh` and `.fun-ci/weekly/soak.sh`
**Then** the project's jobs are `mutation`, daily, and `soak`, weekly, each run
as its script with the commit's hash.
**And** a project without either folder has no jobs, and is valid as before.

### 13.2 `check` lists the jobs and refuses what can't run
**Given** the jobs of 13.1, one of them not executable, or a name in both folders
**Then** `check` lists each job with how often it runs, names a script that
isn't executable, and names a job in both folders; the last two fail `check`,
and no pipeline is stopped for them.

### 13.3 A job is due when it never ran, was cancelled, or ran a period ago
**Given** a daily job whose latest run started 23 h 59 min ago, 24 h ago, was
cancelled a minute ago, or none
**Then** it is due at 24 h, when cancelled and when it never ran, and not
before; a weekly job likewise at 7 days.

### 13.4 Starting a job is claimed in one statement
**Given** two claims of the same due job, one after the other
**Then** one run is recorded; the second claim finds it running and starts nothing.

### 13.5 A job runs once at a time (process)
**Given** a job running in one process
**When** a second process tries it
**Then** the second can't take the job's lock and starts nothing.
*Bites:* two commits a moment apart ran the same job twice.

### 13.6 A job whose process died is recorded failed
**Given** a running job whose lock nobody holds
**When** a claim or the console looks at it
**Then** it is recorded failed, and the claim then follows 13.3.

### 13.7 A background trigger starts the project's due jobs
**Given** a project with a due job, one not due, and another project's due job
**When** `fun-ci trigger --background` runs for a commit of the first project
**Then** only the first project's due job is started, with that commit and
branch, and the pipeline runs as before.

### 13.8 A job runs in a worktree of its own at the commit (process)
**Then** it runs in `<git-common-dir>/fun-ci/jobs/<name>`, checked out at the
commit, with `FUN_CI_JOB` set, and records passed or failed with its exit
status; no pipeline slot is taken.

### 13.9 A job past 24 hours is killed and has run out of time
**Then** with its budget replaced by a test's, an overrunning job is killed
with its process group and recorded `timed_out`, a weekly one as a daily one.

### 13.10 A failed job keeps its evidence
**Then** a failed job's evidence and raw output are kept as a failed stage's
are, with `evidence: jobs: <name>:` entries applied, and collecting it never
changes the outcome.

### 13.11 A newer commit cancels no job
**Given** a running job and a new commit on the branch it tests
**Then** the old pipeline is cancelled and the job runs on.

### 13.12 Each job keeps its 10 newest runs
**Then** an eleventh run deletes the oldest, with its raw output.

### 13.13 `prune` removes the jobs' worktrees too
**Then** it removes them when no job runs, and refuses while one does.

### 13.14 The board carries the jobs
**Then** `board` carries `jobs`: each job of the board's projects, by its
latest run or as due, in the order failed, timed out, running, due, passed,
with when each is due again.

### 13.15 The cursor reaches the jobs, and `c` cancels a running one
**Then** the cursor moves on from the last branch into the jobs, and `c` on a
running job asks first, then kills its processes and records it cancelled.

### 13.16 The page leaves room for the jobs
**Then** a page holds as many branches as fit beside the job section's lines.

### 13.17 A contract fixture holds the jobs conversation on both sides

### 13.18 The renderer draws the job section
**Then** the section is below the last project, the legend's lines end
above it, and each row has its name, how often, its mark and stripe, its
words and its age.

### 13.19 A quiet section folds, and a short screen keeps one line
**Then** with nothing needing you or running it folds to one pale line; on a
short screen it goes to one line before any branch row is folded.

### 13.20 Jobs play no scene
**Then** no event is sent for a job, and the streak and lamp follow runs alone.

### 13.21 `why --job` prints everything kept about a job's latest run
**Given** a weekly job `soak` whose latest run failed, printing `Survived: 3`
**When** an agent runs `fun-ci why --job soak`
**Then** it prints the job, its cadence, the branch and commit it tested,
how it ended (`soak failed (exit 1) after 2.0s, budget 24h`), its evidence,
and the command for its whole output (`fun-ci why --job soak --raw`); it
exits as `why` does for a stage: 0 passed, 1 failed, 2 over budget, 3
running, 5 for a job that never ran.
**And** `--raw` prints the output kept, `--json` the same as one document,
and a name that is no job of the project is a usage error naming the jobs.

### 13.22 `fun-ci jobs` lists the project's jobs
**Then** one line per job: its name, cadence, state, how long its latest run
took, the branch and commit it tested and when, and when it is due again,
or that it runs on the next commit; a `why --job` command after each that
failed or ran over budget; `--json` gives the same as one document. A
project without jobs says where to put them.

### 13.23 `events` tells of jobs
**Then** a job's run starting is `job_started` and ending `job_finished`,
with its state and seconds; `--only failures` keeps the failed and over
budget ones.

### 13.24 `status` names the jobs that ran on the commit
**Then** after the stages, each job whose latest run tested the commit, its
state and the `why --job` command when it failed; `--json` carries them
under `jobs`. The verdict and exit code are the pipeline's alone.

### 13.25 `init` tells agents about the jobs commands
**Then** the instructions it writes name `fun-ci jobs` and `fun-ci why --job`.
