# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle exec rake   # The gate: all tests, cucumber, then rubocop
rake test          # Run all tests (unit + acceptance)
rake unit          # Run unit tests only
rake acceptance    # Run acceptance tests only
bundle exec cucumber           # Run Cucumber feature specs
ruby -Itest -Ilib test/unit/test_trigger.rb                    # Run a single test file
ruby -Itest -Ilib test/unit/test_trigger.rb -n test_method     # Run a single test method
rake contract:capture   # Rewrite contract/golden/ from contract/scenarios/ (after a deliberate TUI change)
```

### CLI (unified entry point)

```bash
fun-ci trigger <commit-hash> <branch>               # Run the full pipeline (pre-push)
fun-ci trigger --no-validate <commit-hash> <branch>  # Fork pipeline to background (pre-commit)
fun-ci console                                       # Launch the TUI dashboard
fun-ci init                                           # Scaffold .fun-ci/ for detected project type
fun-ci init --everything                              # init + install-hooks + check in one step
fun-ci install-hooks                                  # Install pre-commit and pre-push git hooks
fun-ci install-hooks pre-commit                       # Install a single hook type
fun-ci check                                          # Verify .fun-ci/ setup is valid
```

Legacy entry points (`fun-ci-trigger`, `fun-ci-tui`) still exist but are superseded by the unified `fun-ci` CLI.

## 2.0 in progress

Work happens on the `v2` branch. Read `docs/v2/architecture.md` first — it
decides the Ruby/Rust boundary (Ruby decides what is true, Rust decides how it
looks), the renderer protocol and the quality gates. The backlog is
`docs/v2/acceptance-tests.md`, worked in the order of `ralph/build/progress.md`.
Agents run one iteration per worktree via `ralph/agent-in-worktree.sh`.

## What This Is

Fun-CI is an opinionated, local-first CI system for Ruby projects. It runs a four-stage pipeline (lint + build in parallel, then fast suite, then slow suite in background) with strict time budgets (30s lint / 30s build / 10s fast / 5min slow). It uses SQLite with WAL for persistence and has a single CLI entry point with subcommands for triggering pipelines and monitoring via a TUI.

## Architecture

One CLI, multiple subcommands. Source is organized into four module subdirectories under `lib/fun_ci/`:

- **`pipeline/`** -- orchestration and execution
- **`persistence/`** -- SQLite storage and data models
- **`tui/`** -- terminal UI, rendering, animations
- **`setup/`** -- project scaffolding, hooks, validation

### Subcommands

- **`exe/fun-ci`** -> `Cli` routes subcommands to their handlers. Sets up the shared SQLite database and dispatches to the appropriate class.

- **`fun-ci trigger`** -> `pipeline/trigger.rb` orchestrates a pipeline: validates the project config, runs lint and build in parallel, then spawns the slow suite in the background via fork, then runs the fast suite while slow runs. Records all results through `PipelineRecorder` (either `DbRecorder` for real use or `NullRecorder`/`FakeRecorder` in tests).

- **`fun-ci trigger --no-validate`** -> `pipeline/pipeline_forker.rb` forks the entire pipeline into a background process and returns immediately. Used by pre-commit hooks so commits are not blocked.

- **`fun-ci console`** -> `tui/admin_tui.rb` coordinates the live status board. Input handling via `TerminalInput` and `KeyHandler`, data via `BoardData`, rendering via `BoardRenderer` and `Screen`. Runs in raw terminal mode with vim-style navigation (j/k/c/q).

- **`fun-ci init`** -> `setup/installer.rb` detects the project type via `ProjectDetector` and writes template scripts via `TemplateWriter`. Supports Ruby (Bundler), JVM (Gradle Kotlin/Groovy, Maven).

- **`fun-ci install-hooks`** -> `setup/hook_writer.rb` writes git hooks that call `fun-ci trigger`. Pre-commit uses `--no-validate` (background fork); pre-push runs the full pipeline.

- **`fun-ci check`** -> `setup/setup_checker.rb` validates that `.fun-ci/` has all required scripts and they are executable.

### Key classes by module

**`pipeline/`**: `Trigger`, `PipelineForker`, `StageRunner`, `BackgroundWrapper`, `ProcessRunner` (shared module), `ProgressReporter`, `StalePipelineCanceller`

**`persistence/`**: `Database` (SQLite connection + migration), `PipelineRun` / `StageJob` (row wrappers with state machine), `PipelineRecorder` (DbRecorder / NullRecorder)

**`tui/`**: `AdminTui`, `TerminalInput`, `KeyHandler`, `BoardRenderer`, `BoardData`, `RowFormatter`, `Screen` (raw-mode rendering), `HeaderAnimationManager`, animation players and library

**`setup/`**: `ProjectConfig`, `Installer`, `ProjectDetector`, `TemplateWriter`, `HookWriter`, `SetupChecker`, `MavenLinterDetector`

## Testing Conventions

Tests use Minitest. Cucumber features exist for TUI acceptance specs but unit tests are the primary suite.

**Strict rules enforced by the project owner:**
- Tests must be **deterministic** -- no real OS signals, no timeouts, no `Thread.pass`, no polling for real time
- Tests must use **public interfaces only** -- no `instance_variable_get/set`
- If you can't test through the public API, fix the design (add a DI seam)
- Background behavior should be **injected and controlled** by the test, not spawned and polled
- A test run must write **nothing to stderr**: `test/support/stray_stderr_guard.rb` fails the run otherwise (a dying thread or a forked child's exception is an error no test asserted on). Capture output a test expects with `assert_output`/`capture_io`
- A test that forks a real child must wait for it (`Process.waitpid`) before its teardown deletes anything the child uses

**DI seams used throughout:**
- `command_runner` lambda on `Trigger`, `StageRunner`, and `BackgroundWrapper` -- replaces real process spawning in tests
- `background_launcher` lambda on `Trigger` -- controls sync vs async slow suite launch
- `pipeline_forker` callable on `Trigger.run_from_args` -- replaces real fork in `--no-validate` path
- `width_provider` lambda on `AdminTui` -- replaces real terminal width detection
- `commit_validator` lambda on `Trigger` -- replaces real `git cat-file` calls
- `handlers` hash on `Cli` -- overrides subcommand dispatch for testing
- `FakeRecorder` in `test_helper.rb` -- captures recorder calls without touching SQLite

## Golden corpus

`test/acceptance/test_golden_corpus.rb` replays `contract/scenarios/*.jsonl`
through the Ruby renderer and compares every frame with
`contract/golden/<scenario>/NNNN.bytes`. Any change to what the TUI draws fails
it. If the change is deliberate, run `rake contract:capture` and review the
golden diff in the same commit. The renderer never reads `Time.now` itself:
the frame's clock arrives as `Board#now`.

## Code Constraints

- Max **150 lines** per file, max **4 instance variables** per class
- Methods ≤ 7 lines, block nesting ≤ 2, ≤ 4 parameters (keywords count): RuboCop enforces these in the gate. `.rubocop_todo.yml` may only exclude files, and only under `lib/fun_ci/tui/`, `lib/fun_ci/animations/`, or the AT-0.2 list; `test/unit/test_rubocop_todo.rb` enforces that. Fix an offence, never add an exclusion
- TUI runs in raw terminal mode: `\n` alone does NOT carriage-return -- always use `\r\n` (Screen#println handles this)
