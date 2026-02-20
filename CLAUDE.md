# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
rake test          # Run all tests (unit + acceptance)
rake unit          # Run unit tests only
rake acceptance    # Run acceptance tests only
bundle exec cucumber           # Run Cucumber feature specs
ruby -Itest -Ilib test/unit/test_trigger.rb                    # Run a single test file
ruby -Itest -Ilib test/unit/test_trigger.rb -n test_method     # Run a single test method
```

## What This Is

Fun-CI is an opinionated, local-first CI system for Ruby projects. It runs a three-stage pipeline (build → fast suite → slow suite) with strict time budgets (30s / 10s / 5min). It uses SQLite with WAL for persistence and has two entry points: a trigger CLI for git hooks and an admin TUI for monitoring.

## Architecture

Two entry points, two distinct flows:

- **`exe/fun-ci-trigger`** → `Trigger` orchestrates a pipeline: validates the project config, runs build and fast suite synchronously (blocking the commit hook), then spawns the slow suite in the background via `BackgroundWrapper`. Records all results through `PipelineRecorder` (either `DbRecorder` for real use or `NullRecorder`/`FakeRecorder` in tests).

- **`exe/fun-ci-tui`** → `AdminTui` renders a live status board. Reads from SQLite via `BoardData`, formats rows with `RowFormatter`, and renders through `Screen`. Runs in raw terminal mode with vim-style navigation (j/k/c/q).

Key supporting classes:
- `Database` — SQLite connection + migration (two tables: `pipeline_runs`, `stage_jobs`)
- `PipelineRun` / `StageJob` — ActiveRecord-lite row wrappers with state machine transitions
- `Screen` — raw-mode-aware rendering (`\r\n`, `\e[K` per line, `\e[J` after frame)
- `ProjectConfig` — validates `.fun-ci/` directory with build.sh, fast.sh, slow.sh

## Testing Conventions

Tests use Minitest. Cucumber features exist for TUI acceptance specs but unit tests are the primary suite.

**Strict rules enforced by the project owner:**
- Tests must be **deterministic** — no real OS signals, no timeouts, no `Thread.pass`, no polling for real time
- Tests must use **public interfaces only** — no `instance_variable_get/set`
- If you can't test through the public API, fix the design (add a DI seam)
- Background behavior should be **injected and controlled** by the test, not spawned and polled

**DI seams used throughout:**
- `command_runner` lambda on `Trigger` and `BackgroundWrapper` — replaces real process spawning in tests
- `width_provider` lambda on `AdminTui` — replaces real terminal width detection
- `commit_validator` lambda on `Trigger` — replaces real `git cat-file` calls
- `FakeRecorder` in `test_helper.rb` — captures recorder calls without touching SQLite

## Code Constraints

- Max **150 lines** per file, max **4 instance variables** per class
- TUI runs in raw terminal mode: `\n` alone does NOT carriage-return — always use `\r\n` (Screen#println handles this)
