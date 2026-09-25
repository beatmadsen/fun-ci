# CLAUDE.md

Rules and reference for working in this repository: what it is built with,
where things live, what must stay true (each with the test that holds it), and
what bites. `test/policy/test_claude_md.rb` keeps it in that shape.

## Commands

`bundle exec rake` is the gate. It runs every lane below, in this order;
`test/policy/test_gate_lanes.rb` fails if the gate and this list disagree, or if
the docs mention a rake task that is none of a lane, a subset of `rake test`,
or a tool.

### Lanes

```bash
bundle exec rake test       # Every Minitest test: unit, acceptance, integration
bundle exec rake cucumber   # Cucumber feature specs
bundle exec rake rust:test  # cargo test for the Rust renderer (renderer/)
bundle exec rake rubocop    # RuboCop with the project's limits
bundle exec rake rust:clippy # Clippy on renderer/: pedantic, -D warnings, thresholds in renderer/clippy.toml
```

### Subsets of `rake test`, for a quicker loop

```bash
rake unit                                                  # test/unit only
rake acceptance                                            # test/acceptance only
rake integration                                           # test/integration only (process/ included)
rake policy                                                # test/policy only
ruby -Itest -Ilib test/unit/test_stage_runner.rb                # One test file
ruby -Itest -Ilib test/unit/test_stage_runner.rb -n test_method # One test method
```

### Tools

```bash
rake contract:capture   # Rewrite contract/golden/ from contract/scenarios/ (after a deliberate TUI change)
rake mutation           # Mutineer over lib/ except tui/ and animations/ (Ruby >= 3.4); fails below 90 in .mutineer.yml. CI runs it
rake mutation:changed   # The same over lines changed since HEAD; a prompt to look, not a verdict
script/ci-matrix.sh     # The gate as CI runs it (frozen lockfile) on every Ruby in ci.yml, in Docker; or name versions
ruby renderer/tools/convert_animations.rb   # Rewrite renderer/animations/*.json from lib/fun_ci/animations/ (test_animation_json.rb fails on drift)
```

### CLI

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

## Stack

- Ruby >= 3.2 (CI runs 3.2, 3.3, 3.4, 4.0). One runtime dependency: `sqlite3`, in WAL mode.
- Minitest, run in parallel processes by ActiveSupport's executor (serially under `MUTATION_TESTING`); Cucumber for the TUI features; RuboCop; mutineer for the mutation lane (Ruby >= 3.4 only).
- Prism, in tests, to read Ruby sources for the code-limit and call scans.
- 2.0 adds a Rust renderer (`fun-ci-renderer`) that Ruby drives over JSON Lines; `docs/v2/architecture.md` decides the boundary: Ruby decides what is true, Rust decides how it looks.

## Layout

Fun-CI is an opinionated, local-first CI for a project's own machine: a four-stage pipeline (lint and build in parallel, then the fast suite, with the slow suite in the background) under strict time budgets (30 s lint, 30 s build, 10 s fast, 5 min slow), results in SQLite, and a TUI to watch them.

- `exe/fun-ci` -> `Cli` routes subcommands and sets up the shared database (`Cli.run(args, io:, handlers:, db_dir:)`).
- `lib/fun_ci/pipeline/` -- running a pipeline. `TriggerCommand` parses `fun-ci trigger`; `Trigger` validates the project and the commit, records the run and takes a worktree slot from `WorktreePool` (`<git-common-dir>/fun-ci/worktrees/slot-N`, checked out at the commit by `Worktrees`); `SlotRun` runs lint and build in threads there, forks the slow suite (`BackgroundFork`) and runs the fast suite. A `Slot` is held through an flock on `slot-N.lock` by each stage that uses it and frees when the last lets go, or when its holders die; `StageRunner` runs one stage through `CommandExecutor` (an injected runner, or `ProcessRunner` with its budget); `StalePipelineCanceller` cancels the unfinished runs on the same branch through `RunCanceller`, which kills a run's recorded processes (`Persistence::ActiveRuns`: the trigger, the forked slow suite, and each stage script's process group); `PipelineForker` backs `--no-validate`.
- `lib/fun_ci/persistence/` -- `Database` (connection and migration), `PipelineRun` and `StageJob` (row access), `DbRecorder`/`NullRecorder` (what a pipeline records).
- `lib/fun_ci/setup/` -- `init`, `install-hooks`, `check`: `Installer`, `ProjectDetector`, `TemplateWriter`, `HookWriter`, `SetupChecker`, `ProjectConfig`.
- `lib/fun_ci/tui/`, `lib/fun_ci/animations/` -- the 1.x console, the renderer 2.0 replaces: `AdminTui`, `BoardData`, `KeyHandler`, `BoardRenderer`, `Screen`, animation players and data.
- `contract/` -- renderer scenarios, the Ruby renderer's golden frames and the capture tool. `docs/v2/` -- the 2.0 architecture, renderer protocol and backlog (`acceptance-tests.md`, worked in the order of `ralph/build/progress.md`). `ralph/` -- the agent build loop (`docs/v2/agentic-pipeline.md`).
- `test/unit/` (one class, in memory), `test/acceptance/` (a user-facing command or flow), `test/integration/` (SQLite, filesystem), `test/policy/` (checks on the repository itself: lanes, limits, CLAUDE.md, CI), `test/integration/process/` (real processes and git), `test/integration/process/end_to_end/` (whole pipelines with real git and stage scripts; slow, and left out of the mutation lane), `test/support/` (guards, scanners, test kits), `features/` (Cucumber).

Seams tests use in place of the real thing:
- `Trigger.new(project:, commit:, io:, seams:)` and `StageRunner.new(commit_hash:, stdout:, seams:)` take a `Pipeline::Seams` (`lib/fun_ci/pipeline/trigger_params.rb`): `command_runner` (stage processes), `background_launcher` (`nil` is the real fork), `commit_validator` (`git cat-file`), `recorder`, `time_budgets`, `workspace` (`nil` is the worktree pool; `InPlace` runs in the project directory itself). Each left out gets the real thing; `test/support/trigger_test_kit.rb` builds one the way tests need it.
- `pipeline_forker` on `Trigger.run_from_args` (the `--no-validate` fork), `handlers` and `db_dir` on `Cli.run`, `open:` on `Database.connection`.
- `width_provider` and `terminal_input` on `AdminTui`; the cucumber lane drives `AdminTui#run` in a fiber (`features/support/run_loop.rb`).
- `FakeRecorder` in `test/test_helper.rb` captures recorder calls without SQLite.

## Invariants

- The gate runs exactly the lanes listed under Lanes, and every rake task the docs mention is a lane, a subset of `rake test`, or a tool: `test/policy/test_gate_lanes.rb`.
- Methods of at most 7 lines, block nesting of at most 2, at most 4 parameters (keywords count): RuboCop in the gate. `.rubocop_todo.yml` only excludes files, and only under `lib/fun_ci/tui/` and `lib/fun_ci/animations/`: `test/policy/test_rubocop_todo.rb`. Fix an offence; never add an exclusion.
- No Ruby file longer than 150 lines (the animation data modules aside until §3.6), no class or module with more than 4 instance variables: `test/policy/test_code_limits.rb`.
- Tests wait on nothing real and reach state through public interfaces: no `sleep`, `Thread.pass`, `Timeout.timeout` or `instance_variable_get/set` in `test/` or `features/`: `test/policy/test_tests_are_deterministic.rb`. Background work is injected and driven by the test, not spawned and polled; if a test can't get at something through the public API, add a seam.
- A test run writes nothing to stderr (a dying thread or a forked child's exception is an error no test asserted on); capture expected output with `assert_output`/`capture_io`: `test/integration/process/test_stray_stderr_guard.rb`.
- Every SQLite connection a test opens is closed by the end of that test, since a leaked one is inherited by the next fork in the same worker: `test/integration/process/test_sqlite_connection_guard.rb`.
- Tests touch only the run's private temp root, which `TMPDIR` points at: no file written, database opened or git run outside it. Build paths from `Dir.mktmpdir`/`Dir.tmpdir`, never from the repository or `$HOME`: `test/integration/process/test_confinement_guard.rb`, `test/policy/test_confinement_guard_installed.rb`.
- Only tests under `test/integration/process/` start processes, send real signals or run git, directly or through the code they call (signals: directly): `test/policy/test_fast_lanes_never_spawn.rb` (a Prism scan of unit and acceptance sources) and `test/integration/process/test_spawn_guard.rb` (the runtime guard for every other test).
- What the Ruby TUI draws matches `contract/golden/`, frame for frame, and capturing twice gives identical bytes (the renderer takes its clock from `Board#now`, never `Time.now`): `test/acceptance/test_golden_corpus.rb`. After a deliberate change, run `rake contract:capture` and review the golden diff in the same commit.
- The gem ships exactly the tracked files under `lib/` and `exe/` plus README, CHANGELOG and LICENSE, and keeps its publishing metadata: `test/integration/process/test_gemspec_contents.rb`.
- CI runs the gate on Ruby 3.2, 3.3, 3.4 and 4.0 with fail-fast off, and the mutation lane on 3.4: `test/policy/test_ci_workflow.rb`.
- fun-ci processes set up a database one at a time (a lock file beside it), so concurrent hooks never die on a fresh database: `test/integration/test_database_setup_lock.rb`, `test/integration/process/test_database_concurrent_setup.rb`.
- `fun-ci trigger` closes every database connection it opens: `test/acceptance/test_cli_subcommands.rb`.
- This file keeps Stack, Layout, Invariants and Gotchas, and every invariant names a test that exists: `test/policy/test_claude_md.rb`.

## Gotchas

- The TUI runs in raw terminal mode, where `\n` alone does not return the carriage: write `\r\n` (`Screen#println` does).
- A test that forks a real child waits for it (`Process.waitpid`, or joins its `Process.detach` waiter) before teardown deletes anything the child uses. A forked child also holds its own copy of every pipe end: close the write end in the child before reading to EOF, or the read never ends.
- After the slow suite forks, `Trigger` holds a fresh recorder, because a child must not inherit an open SQLite connection. Release it with `Trigger#close`, not with the recorder you passed in.
- The lockfile has to install on every Ruby in `.github/workflows/ci.yml`: the Gemfile pins `parallel < 2` (2.x needs Ruby 3.3) and wraps mutineer in `install_if`, not `if RUBY_VERSION`, which a frozen bundle rejects. Check with `script/ci-matrix.sh`.
- Loading `fun_ci.gemspec` runs `git ls-files`, which the guards forbid in-process: tests load it in a child Ruby (`test/support/gemspec_probe.rb`) outside Bundler's environment.
- macOS scans every freshly written executable on its first exec (130-250 ms), so tests that write and run stage scripts are slow there. That is why `test/integration/process/end_to_end/` is left out of the mutation lane: the Trigger mutants those tests cover overran mutineer's 10 s cap.
- The mutation score is killed / (killed + survived). Code that runs only in a forked child shows as no-coverage, not as a pass. Mutineer attributes methods defined in a `Data.define` block to the enclosing module, so reopen the class to define them (`Pipeline::Seams`).
- Minitest shows two long strings that differ by shelling out to `diff -u`, which the spawn guard would turn into an error that hides the failure. `test/test_helper.rb` sets `Minitest::Assertions.diff = nil`, so failures print plain Expected/Actual.
- ActiveSupport's parallel executor puts a Unix socket in `Dir.tmpdir`, and socket paths are capped at 104 bytes, which is why the test temp root has a short name.
