# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-23

### Bug Fixes
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
