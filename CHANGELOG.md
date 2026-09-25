# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- The hook that runs a pipeline in the background is now `post-commit`,
  so it tests the commit you just made; the `pre-commit` hook tested the
  commit before it. `fun-ci install-hooks` writes `post-commit` and
  `pre-push`. `fun-ci trigger --background` is the new name for
  `--no-validate`, which still works until 2.1 and says so on stderr.
  `install-hooks` removes the `pre-commit` hook fun-ci 1.x wrote. A
  `pre-commit` hook of your own is left alone, and if it still calls
  fun-ci, `fun-ci check` warns you to take that out.
- Every pipeline now runs in a git worktree of its own, checked out at the
  commit it is testing, under `.git/fun-ci/worktrees/`. Before, the stages ran
  in your checkout while you kept editing it. The stage scripts come from the
  commit too, unless it has no `.fun-ci/`, in which case the checkout's are
  used. Two pipelines run at once by default; set `worktree_slots: 3` (or
  any number above 0) in `.fun-ci/config` for more.
- The console's cancel prompt names the run it would cancel, as in
  `Cancel feat/search (d4e5f67)? y / n`, instead of the generic
  "Cancel running pipeline? y/n".

### Removed
- The `fun-ci-trigger` and `fun-ci-tui` executables. Use `fun-ci trigger` and
  `fun-ci console`, which have done the same job since 1.0.

### Bug Fixes
- Git runs hooks with variables such as `GIT_INDEX_FILE` pointing at the
  checkout. fun-ci passed them on to the git commands it runs and to your
  stage scripts, which then read the checkout's index instead of the
  commit's. They are cleared now.
- Cancelling a stale pipeline (a newer commit on the same branch) left its
  stage scripts running and could let the old run record itself as failed
  after it was cancelled. fun-ci now records every process a run starts and
  stops all of them, its own first, and cancels runs still waiting for a
  worktree as well. A run that had already died is only marked cancelled:
  the process ids it left behind may belong to something else by now.
- Cancelling a run from the console (`c`, then `y`) only marked it
  cancelled; its stages kept running. It now stops the run the same way,
  whether the fast suite is still running or only the slow suite is left.
- Two fun-ci processes starting at the same moment against a database that
  didn't exist yet (the first commit and push on a machine, say) could die
  with `database is locked` or `duplicate column name: project_path`.
  Setting up the database now takes a lock file beside it, so they take
  turns.
- The phase 1 line printed lint and build in whichever order they finished,
  so the same result could read `build ok  lint ok`. Lint always comes first
  now.
- A project's name in the console changed colour every time the console
  started, because the colour came from `String#hash`, which Ruby seeds per
  process. It now comes from a CRC-32 of the name and stays the same.

## [1.2.1] - 2026-09-20

### Bug Fixes
- Git runs hooks with variables such as `GIT_INDEX_FILE` pointing at the
  checkout. fun-ci passed them on to the git commands it runs and to your
  stage scripts, which then read the checkout's index instead of the
  commit's. They are cleared now.
- `StageRunner` raised `NameError: uninitialized constant FunCi::NullRecorder`
  when built without an explicit recorder. The module reorganisation in 1.2.0
  moved `NullRecorder` under `Persistence` and the default argument was left
  pointing at the old name. The file also never required the recorder it names,
  so the constant was only ever resolvable by luck of load order.

### Changed
- The hook that runs a pipeline in the background is now `post-commit`,
  so it tests the commit you just made; the `pre-commit` hook tested the
  commit before it. `fun-ci install-hooks` writes `post-commit` and
  `pre-push`. `fun-ci trigger --background` is the new name for
  `--no-validate`, which still works until 2.1 and says so on stderr.
- The gemspec reads the version from a new `lib/fun_ci/version.rb` instead of
  loading the whole library. Loading the library pulls in sqlite3, and Bundler
  reads the gemspec before it installs anything, so `bundle install` failed on
  any machine that did not already happen to have sqlite3.
- `required_ruby_version` is now `>= 3.2`. The stated floor of 3.0 was never
  reachable: the TUI uses `Data.define`, which arrived in Ruby 3.2.

### Internal
- The cucumber suite had been broken since the 1.2.0 reorganisation, which moved
  the files and constants it loads. It runs again, `rake` runs it, and it runs
  with `--strict` so an undefined step fails instead of passing quietly.
- `StageRunner` has tests. It had none, which is how the broken default survived.

## [1.2.0] - 2026-02-23

### Bug Fixes
- Git runs hooks with variables such as `GIT_INDEX_FILE` pointing at the
  checkout. fun-ci passed them on to the git commands it runs and to your
  stage scripts, which then read the checkout's index instead of the
  commit's. They are cleared now.
- Replaced unreliable `Timeout.timeout` with process groups (`pgroup: true`) and `Thread#join` for reliable time budget enforcement on lint/build/fast/slow stages
- Fixed off-by-one in TUI row truncation that caused the top pipeline row to be hidden behind the header in short terminals
- Added `Screen#height=` to clear screen on terminal height changes, preventing the header from scrolling off-screen when tmux panes resize
- Fixed header flicker by skipping `println` when animation is active
- Allowed null SHA on root commits so pipeline still runs
- Detected multi-module Gradle projects from `settings.gradle`

### Refactoring
- Extracted `TerminalInput`, `KeyHandler`, `BoardRenderer` from `AdminTui` (was 257 lines/12 ivars, now 4 focused classes all under 150 lines/4 ivars)
- Organized flat `lib/fun_ci/` into cohesive module subdirectories: `persistence/`, `pipeline/`, `setup/`, `tui/`

### Internal
- Extracted shared `ProcessRunner` module for consistent process spawning across stages
- Updated `BackgroundWrapper` to use `[output, status, timed_out]` triples instead of exception-based timeout signaling
- Truncated TUI board rows to fit terminal height

## [1.1.0] - 2026-02-22

### Added
- Multi-line ASCII art header animations for pipeline events (explosion on failure, celebrations on success)
- Looping idle starfield animation in the TUI header
- Rocket animation while pipelines are running, with flickering exhaust and parallax starfield
- HeaderAnimationManager with idle/running/event state transitions
- AnimationLibrary with 8 animation data files (explosion, success, celebrate, flash, leprechauns, yay, idle, running)

### Fixed
- Footer animations now display 8x slower so text is actually readable
- Animation refresh no longer blocks for 5 seconds between frames when no pipelines are running
- Removed stale single-line header banner that conflicted with multi-line animations
- Animation frames padded to global max width across all frames, preventing horizontal jitter

## [1.0.0] - 2026-02-21

### Added
- Four-stage local CI pipeline (lint, build, fast, slow) with strict time budgets (30s/30s/10s/5min)
- Unified CLI (`fun-ci`) with subcommands: trigger, console, init, install-hooks, check
- Pre-commit hook (background fork, non-blocking) and pre-push hook (synchronous, blocking)
- TUI dashboard with vim-style navigation (j/k/c/q), pagination, and project path display
- Project scaffolding with built-in templates for Ruby (Bundler), JVM (Gradle Kotlin/Groovy, Maven)
- SQLite persistence with WAL mode for pipeline results
- Parallel lint + build stages with background slow suite
- Smart Maven linter detection for template generation
- Stale pipeline auto-cancellation
