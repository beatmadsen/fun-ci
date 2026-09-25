---
agent: ralph/agent-in-worktree.sh
commands:
  - name: done_check
    run: bash -c 'test -f ralph/build/DONE && echo ALL_DONE || echo NOT_DONE'
    timeout: 5
  - name: progress
    run: cat ralph/build/progress.md
    timeout: 5
  - name: recent_iterations
    run: bash -c 'tail -15 ralph/log.tsv 2>/dev/null || echo "No iterations yet"'
    timeout: 5
  - name: recent_commits
    run: git log --oneline -10
    timeout: 5
  - name: architecture
    run: cat docs/v2/architecture.md
    timeout: 5
  - name: protocol
    run: cat docs/v2/renderer-protocol.md
    timeout: 5
  - name: acceptance_tests
    run: cat docs/v2/acceptance-tests.md
    timeout: 5
  - name: gate
    run: bash -c 'set -o pipefail; CUCUMBER_OPTS="--format progress" bundle exec rake 2>&1 | tail -60; echo "gate exit status $?"'
    timeout: 600
---

# fun-ci 2.0 build loop

Run from the repository root with the trunk (`main`) checked out.
`ralph/agent-in-worktree.sh` gives you a fresh worktree on a new branch; you
are already inside it. Relative paths only.

## Completion check

{{ commands.done_check }}

**If the output above says `ALL_DONE`, output "Nothing to do." and exit.**

## Context

### Architecture and decisions
{{ commands.architecture }}

### Renderer protocol
{{ commands.protocol }}

### Acceptance tests
{{ commands.acceptance_tests }}

### Progress
{{ commands.progress }}

### Recent iterations (landed / rejected, with reason)
{{ commands.recent_iterations }}

### Recent commits
{{ commands.recent_commits }}

### Gate output on the integration branch
{{ commands.gate }}

## Your task — iteration {{ ralph.iteration }}

Exactly one unit of work, exactly one commit. The wrapper rejects the iteration
if you make zero or several commits, leave uncommitted changes, or if
`bundle exec rake` is red in your worktree after you finish.

1. If every item in `ralph/build/progress.md` is ticked, create
   `ralph/build/DONE`, commit it as "Finish the 2.0 build loop", and stop.
2. If the last 10 ticked items contain no `R<n>` refactor entry, this is a
   **refactor iteration**: no new behaviour; remove duplication and awkward
   seams the recent items introduced; keep the gate green; append
   `- [x] R<n>: <summary>` to progress.md.
3. Otherwise take the **first unchecked** item. If the last iteration on the
   same item was rejected, read its reason in the log and do something
   different. If an outline item (§3–§6) is too vague to test, your one commit
   is to refine its acceptance test in `docs/v2/acceptance-tests.md` (and
   split it in progress.md if needed) — no code.
4. ATDD: acceptance test first and see it fail for the right reason; unit tests
   for non-trivial inner code; make it pass; refactor within the limits.
5. If the item adds a gate, prove it bites: introduce a violation, run the
   gate, see it fail, revert. Say so in the commit body.
6. Tick the item. Update CHANGELOG `Unreleased` for user-visible changes and
   CLAUDE.md when you add an invariant or discover a gotcha.
7. Commit specific files (never `git add -A`). Subject: `AT-x.y: <behaviour in
   plain imperative English>`. Body: why, and how you verified it. End with the
   `Co-Authored-By` trailer for the model you are.

## Standards (non-negotiable)

- Methods ≤ 7 lines, nesting ≤ 2, ≤ 4 parameters (keywords count), ≤ 150
  lines per file, ≤ 4 instance variables per class. Rust: clippy pedantic,
  `-D warnings`, thresholds in `clippy.toml`.
- Deterministic tests: injected clocks, runners and launchers. No sleeps, no
  real signals, no polling, no `Timeout`.
- Public interfaces only in tests; if you can't test it, add a seam.
- Tests touch only temp directories. Spawning processes or using real git is
  only allowed in `test/integration/process/`.
- Name tests for the behaviour they pin, never for the event that caused them.
- Don't weaken a limit, threshold or test to get green. If one is genuinely
  wrong, stop and write why in `ralph/build/QUESTIONS.md` as your commit.
