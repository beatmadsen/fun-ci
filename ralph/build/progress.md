# Build loop progress

Order is deliberate: 2.6 comes first so the golden corpus pins today's renderer
before §0 refactors `tui/`. After every 10 ticked items the next iteration is a
refactor iteration (no new behaviour) — record it as `- [x] R<n>: <summary>`.

- [x] AT-2.6: Scenarios capture the current Ruby renderer as golden output
- [x] AT-0.1: RuboCop is part of the gate with the project's limits
- [x] AT-0.2: Constructor parameter objects replace long keyword lists
- [x] AT-0.3: The cucumber lane and every documented lane run in the gate
- [x] AT-0.4: Tests are confined to temp directories
- [x] AT-0.5: Unit and acceptance tests never spawn processes
- [x] AT-0.6: Mutation testing lane
- [x] AT-0.7: CI runs the gate on every supported Ruby
- [x] AT-0.8: The gem ships exactly the tracked runtime files
- [x] AT-0.9: CLAUDE.md is written as Invariants and Gotchas
- [x] AT-0.10: Legacy executables are gone
- [x] AT-1.1: A pipeline runs in a worktree at the requested commit
- [x] AT-1.2: Uncommitted changes don't leak into a run
- [x] AT-1.3: Ignored caches survive between runs in the same slot
- [x] AT-1.4: The slot stays taken until the background slow suite finishes
- [x] AT-1.5: Crashed runs don't leak slots
- [x] AT-1.6: Cancelling a stale run frees its slot
- [x] AT-1.12: Cancelling from the console stops the run
- [x] AT-1.7: Pool size is configurable
- [x] AT-1.8: The background hook is post-commit and records the new commit
- [x] AT-1.9: Upgrading replaces fun-ci's own pre-commit hook only
- [x] AT-1.10: `--no-validate` keeps working as an alias for one release
- [x] AT-1.11: Worktrees are cleaned up with `fun-ci prune`
- [x] AT-2.1: ConsoleSession separates state from rendering
- [x] AT-2.2: `board` messages follow the protocol
- [x] AT-2.3: Stage changes become events, not animations
- [x] AT-2.4: Resize changes the page size
- [x] AT-2.5: Protocol errors never crash the console
- [x] AT-3.1: `renderer/` Cargo crate `fun-ci-renderer`
- [x] AT-3.2: Handshake
- [x] AT-3.3: Headless mode writes `frames.jsonl`, `frames/NNNN.png`, `sheet.png`, `frames.cast`, `stats.json`
- [x] AT-3.4: Differential tests
- [x] AT-3.5: Contract fixtures
- [x] AT-3.6: Animations load from `renderer/animations/*.json` (converted from the Ruby modules by a one-off script, checked in)
- [x] AT-3.7: Terminal is restored on EOF, `quit`, panic and SIGTERM
- [x] AT-3.7b: The cancel prompt names the branch and short SHA
- [x] AT-3.8: `rake contract:binary` drives the real binary in the gate
- [x] AT-3.9: cargo-mutants lane ≥ 90 % caught
- [x] AT-4.1: Renderer lookup
- [x] AT-4.2: Platform gems for the five targets built in CI
- [x] AT-4.3: `cargo install fun-ci-renderer` path documented and tested in CI
- [x] AT-5.1: `fun-ci console` uses the Rust renderer
- [x] AT-5.2: Golden byte files become Rust `insta` snapshots
- [x] AT-5.3: Cucumber TUI features are rewritten against headless frames or deleted where the Rust suite covers them
- [x] AT-5.3b: Ruby `tui/` rendering and `animations/` are deleted
- [x] AT-5.4: README, CHANGELOG, version 2.0.0
- [ ] AT-6.1: Objective visual gates from `stats.json` and `frames/` in `rake`
- [ ] AT-6.2: TUI rubric (`docs/v2/tui-rubric.md`)
- [ ] AT-6.3: Polish evaluator prompt
- [ ] AT-6.4: Polish iterator prompt
- [ ] AT-6.5: `rake polish:approve` after review in a real terminal
- [x] R1: One ProbeSuite helper replaces the guard tests' own probe runners; CallScanner.scan replaces two hand-rolled source scans
- [x] R2: RunCanceller#cancel is the one stop-and-record the stale canceller and the console share; one Descendants helper waits for a command and everything it started
- [x] R3: KeyHandler, BoardData, StageChangeDetector and StreakCounter move from tui/ to console/, which keeps them, and meet the limits; StageJob.for_run holds BoardData's SQL
