# fun-ci 2.0 — Acceptance tests

Numbered like agent-tome's. The build loop implements them in order, one per
iteration. Sections 0–2 are fully specified; 3–5 are specified far enough to
start and will be refined as earlier sections land (each refinement is its own
commit to this file).

Where a test says "the gate", it means `bundle exec rake` (default task).

---

## 0. Quality baseline (intent-record standards)

### 0.1 RuboCop is part of the gate with the project's limits
**Given** `.rubocop.yml` with `Metrics/MethodLength: 7`, `Metrics/BlockNesting: 2 (CountBlocks: true)`, `Metrics/ParameterLists: 4`, `TargetRubyVersion: 3.2`, `NewCops: enable`
**When** the gate runs
**Then** rubocop runs after the tests and the gate fails on any offence.
*Bites:* a commit shows a deliberate 8-line method failing the gate, then reverted.
*Note:* existing offences are fixed, not excluded — split into several AT-0.1.x
commits by directory (`setup/`, `persistence/`, `pipeline/`, `tui/`). `tui/`
may use a directory-scoped `.rubocop_todo.yml` since it is deleted in §5.

### 0.2 Constructor parameter objects replace long keyword lists
**Given** `Trigger.new` takes 10 keyword arguments
**When** ParameterLists (4, keywords counted) is enforced
**Then** collaborators are grouped (`Trigger.new(project:, commit:, io:, seams:)`), and every existing DI seam listed in CLAUDE.md is still injectable.

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

### 0.8 The gem ships exactly the tracked runtime files
**Given** the gemspec
**Then** `spec.files` comes from `git ls-files` minus `test/`, `features/`, `docs/`, `ralph/`, `contract/`, dotfiles, CLAUDE.md, and a test asserts no such path is in `spec.files`.

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
**Then** fun-ci's 1.x hook is removed; a user's hook is left alone and `fun-ci check` warns that it doesn't call fun-ci.

### 1.10 `--no-validate` keeps working as an alias for one release
**When** `fun-ci trigger --no-validate <sha> <branch>` runs
**Then** it behaves like `--background` and prints a one-line deprecation notice to stderr.

### 1.11 Worktrees are cleaned up with `fun-ci prune`
**When** `fun-ci prune` runs with no pipeline active
**Then** all fun-ci worktrees and their admin entries (`git worktree prune`) are removed.

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
**Given** each scenario in `contract/scenarios/` (empty, happy-7, running, fail-explosion, success-fireworks, narrow-60, wide-200, resize-mid-animation)
**When** `rake contract:capture` runs
**Then** it writes `contract/golden/<scenario>.bytes` using today's `BoardRenderer` driven by a fake clock, and running it twice produces identical files.

---

## 3. Rust renderer to parity (outline)

- 3.1 `renderer/` Cargo crate `fun-ci-renderer`; `rake` runs `cargo test` and `cargo clippy -D warnings` with the thresholds from architecture.md. Bites shown.
- 3.2 Handshake: `hello v1` → `ready`; unknown version → `error version`, exit 2.
- 3.3 Headless mode writes `frames.jsonl`, `frames.cast`, `sheet.svg`, `stats.json`.
- 3.4 Differential tests: for every scenario, the `vt100` cell grid of the Rust output equals that of `contract/golden/<scenario>.bytes`, frame by frame.
- 3.5 Contract fixtures: the Rust suite accepts every fixture's Ruby→renderer lines and emits its renderer→Ruby lines.
- 3.6 Animations load from `renderer/animations/*.json` (converted from the Ruby modules by a one-off script, checked in).
- 3.7 Terminal is restored on EOF, `quit`, panic and SIGTERM.
- 3.8 `rake contract:binary`: Ruby drives the real binary through a pty for the `happy-7` fixture. In the gate.
- 3.9 cargo-mutants lane ≥ 90 % caught.

## 4. Distribution (outline)

- 4.1 Renderer lookup: `FUN_CI_RENDERER` → bundled `libexec/` → `PATH`; missing renderer makes only `console` fail, with install instructions.
- 4.2 Platform gems for the five targets built in CI; each installed into an empty `GEM_HOME` and smoke-tested headless.
- 4.3 `cargo install fun-ci-renderer` path documented and tested in CI.

## 5. Cut-over (outline)

- 5.1 `fun-ci console` uses the Rust renderer; Ruby `tui/` rendering classes and `animations/` are deleted.
- 5.2 Golden byte files become Rust `insta` snapshots; `contract:capture` is removed.
- 5.3 Cucumber TUI features are rewritten against headless frames or deleted where the Rust suite covers them.
- 5.4 README, CHANGELOG, version 2.0.0.

## 6. Polish loop (outline — see agentic-pipeline.md)

- 6.1 Objective visual gates from `stats.json` in `rake`.
- 6.2 `docs/v2/tui-rubric.md`.
- 6.3 `ralph/polish/` evaluator + iterator prompts; `rake polish:approve`.
