# fun-ci Roadmap

Does not include completed work.

## 2.0.0 — Rust renderer, worktree isolation, agent-built

Plan and decisions: [docs/v2/architecture.md](docs/v2/architecture.md)
Acceptance tests: [docs/v2/acceptance-tests.md](docs/v2/acceptance-tests.md)
Live checklist: [ralph/build/progress.md](ralph/build/progress.md)

| Phase | Outcome | Exit criterion |
|---|---|---|
| 0. Quality baseline | intent-record standards on today's code | `rake` = tests + cucumber + rubocop, all green; mutineer ≥ 90 in CI |
| 1. Worktree isolation | Every pipeline runs in a pooled worktree at its own SHA; post-commit hook | §1 acceptance tests green; could ship as 1.3.0 |
| 2. Protocol + golden corpus | `ConsoleSession` speaks the protocol; golden frames captured from the Ruby renderer | §2 green; `contract/golden/` checked in |
| 3. Rust renderer to parity | Cell-grid equality with the golden corpus for every scenario | §3 green, `cargo-mutants` ≥ 90 % |
| 4. Distribution | Platform gems install and run on five targets | §4 green in CI |
| 5. Cut-over | Ruby rendering deleted; 2.0.0 released | §5 green |
| 6. Polish loop | Agents evaluate and iterate on the TUI with human-approved snapshots | §6 green; first polish round merged |

Built by the loop in [ralph/build/RALPH.md](ralph/build/RALPH.md); see
[docs/v2/agentic-pipeline.md](docs/v2/agentic-pipeline.md).
