# Specifications for fun-ci

## Principles

### It's fun! 
An atmosphere of experimentation and having fun with trying to break the app by exposing it to integration and testing

### It's simple!
Keep the interface and interactions straightforward and easy to understand.

### It's fast!
While ruby isn't fast, the interaction is designed so that we fail fast and get feedback quickly, allowing for a more enjoyable experience.

### It's reliable!
We're here to provide a safety net for your code, so ours better well work!

### It's opinionated!
"Continuous" in CI means your pipeline is fast and your feedback is fast. We will fail if your pipeline is not up to the standard as a way to inform you that you need to keep up and invest in better. Concrete time budgets enforce this:
- **Build stage: 30 seconds.** If your build takes longer than 30 seconds, the run is killed and treated as a failure. This encourages you to keep your build efficient and not let it become a bottleneck.
- **Fast suite: 10 seconds.** If your fast tests take longer than 10 seconds, the run is killed and treated as a failure. This is a feature, not a bug -- it tells you your fast suite has grown too heavy and needs attention.
- **Slow suite: 5 minutes.** The slow suite gets more room, but 5 minutes is the hard ceiling. If your integration tests can't finish in 5 minutes, that's a signal to split, pare down, or parallelise.

## Features

### Divides the world into the slow suite and the fast suite

### Made for commit hooks

### Scheduled jobs with full state machines

### Does not ingest or track build artefacts or logs

### Admin TUI for monitoring and managing scheduled jobs


## Project Configuration

A project that uses fun-ci provides its pipeline hooks via a `.fun-ci/` folder in the project root containing three executable shell scripts:

- `.fun-ci/build.sh` — the build stage
- `.fun-ci/fast.sh` — the fast test suite
- `.fun-ci/slow.sh` — the slow test suite

Each script is invoked by fun-ci with the commit hash as the first argument. The script's exit code determines pass (0) or fail (non-zero). Scripts that exceed their time budget are killed.

## Architecture

### Multiple entry points for different use cases:
- Trigger CLI for git hooks and manual triggers
- Admin TUI for user access and monitoring

### State machine for scheduled jobs:
- States: Scheduled, Running, Completed, Failed
- Each pipeline stage has its own scheduled job. 
- Stages: Build, Fast Suite (10s budget), Slow Suite (5min budget)


### Concurrent, modest frequency reads

### Concurrent, low frequency writes
It's not every second a developer commits new code to a project. 

### Sqlite with WAL is good enough for our needs.


### Trigger inovocation orchestrates the jobs for the associated commit. 
- Trigger CLI is invoked with the commit hash and branch name.
- It will spawn off a background process with a strict deadline to drive and complete the pipeline or fail. This code must be deeply resillient and not cause orphaned processes or memory leaks.
- It will wait in the foreground until the fast suite is complete and return the result of that suite; return code 0 for success, non-zero for failure.


## Failure Modes

Every failure the developer encounters should be understandable in one glance and recoverable without digging through internals. The system should make the *cause* obvious and the *next step* clear.

| Scenario | What the developer sees | Exit code | State machine transition | Recovery / next step |
|---|---|---|---|---|
| **Build stage fails** | Inline compiler/bundler output, then: "Build failed. Fix the errors above and commit again." | non-zero | Running -> Failed | Fix the build error and re-commit. No cleanup needed. |
| **Fast suite tests fail** | Test runner output (pass/fail summary), then: "Fast suite failed. Your commit hook is blocked until tests pass." | non-zero | Running -> Failed | Fix the failing tests and re-commit. The hook is doing its job. |
| **Fast suite exceeds 10s budget** | Test output interrupted mid-stream, then: "Fast suite killed -- exceeded 10s time budget. Your fast tests have gotten too slow. Split or speed them up." | non-zero | Running -> TimedOut | Move slow tests to the slow suite, optimise, or split. This is a design signal, not a flaky failure. |
| **Slow suite tests fail** | Visible in TUI as a failed job. Summary line: "Slow suite failed for abc1234. N tests failed." TUI offers drill-down to see which tests. | n/a (background) | Running -> Failed | Investigate failures via TUI, fix, and push again. Does not block the commit hook. |
| **Slow suite exceeds 5min budget** | Visible in TUI: "Slow suite killed -- exceeded 5min time budget for abc1234." | n/a (background) | Running -> TimedOut | Pare down integration tests, parallelise, or raise the budget if genuinely justified. |
| **SQLite database is locked** | Retry transparently (up to 3 attempts with brief backoff). If still locked: "fun-ci: database busy, could not record result. Your tests still ran -- re-trigger to update status." | non-zero | No transition (write failed) | Wait a moment and re-trigger, or check for stuck processes with the TUI. |
| **Background process crashes** | The foreground trigger detects the lost process: "fun-ci: background pipeline for abc1234 died unexpectedly. Fast suite result is still valid. Slow suite will not run." Job marked as Failed in DB. | 0 if fast suite passed before crash; non-zero otherwise | Running -> Failed | Re-trigger manually via CLI or let the next commit pick it up. TUI shows the failed job for visibility. |
| **Orphaned process from previous run** | On trigger, fun-ci checks for an existing process for the same branch. If found: kills it, marks the old job as Cancelled, then starts fresh. Developer sees: "Cancelled stale pipeline for abc1234. Starting fresh for def5678." | (continues normally) | Running -> Cancelled (old job) | No action needed. The system cleans up after itself. |
| **Git hook invoked but fun-ci not installed** | The hook script checks for the `fun-ci` binary first. If missing: "fun-ci is not installed or not in PATH. Commit will proceed without CI. Install with: gem install fun-ci" | 0 (don't block commits) | n/a | Install fun-ci. The hook is a safety net, not a gate -- a missing tool should never strand a developer. |
| **Git hook invoked but no .fun-ci/ folder** | fun-ci binary exists but no `.fun-ci/` folder found: "No .fun-ci/ folder found. Create .fun-ci/build.sh, fast.sh, and slow.sh to set up this project. Commit will proceed without CI." | 0 (don't block commits) | n/a | Create the `.fun-ci/` folder with the three hook scripts. Commit goes through so the developer isn't stuck. |
| **Hook script missing or not executable** | One of the expected scripts is missing or lacks execute permission: "fun-ci: .fun-ci/fast.sh is not executable (or not found). Commit will proceed without CI." | 0 (don't block commits) | n/a | Add the missing script or `chmod +x` it. |
| **Concurrent triggers for the same branch** | Second trigger detects an in-flight pipeline for the same branch. Cancels the older one: "Pipeline already running for main (abc1234). Cancelling it and starting fresh for def5678." | (continues normally) | Running -> Cancelled (old job) | No action needed. Latest commit always wins. |
| **Trigger invoked with invalid commit/branch** | Immediate validation: "fun-ci: commit abc1234 not found in this repository." or "fun-ci: branch name is required." | non-zero | n/a (never scheduled) | Check the arguments. Likely a misconfigured hook. |
| **Disk full / cannot write to database** | "fun-ci: cannot write to database at ~/.fun-ci/db.sqlite3. Check disk space." | non-zero | No transition | Free disk space. fun-ci does not create temp files or artefacts, so the issue is external. |

