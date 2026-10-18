# Field reports

**Document type:** an inbox of problems seen while using fun-ci in other projects.
Each entry says what was observed, how to reproduce it, and whether it was seen or inferred.
An agent picking one up fixes it under the repo's usual discipline (failing test first), then deletes the entry.

---

## Node template: lint and build race over `node_modules` in a fresh worktree

- **Inferred, not reproduced.** The `node_npm` template is lint `npx eslint .`, build `npm install`. The
  README says lint and build run in parallel on the same worktree, and a new worktree has no `node_modules`.
  So on a first run lint starts before `npm install` has finished: `npx` would either fetch a registry eslint
  or fail to resolve the plugins `eslint.config.js` imports. Later, a lockfile change makes `npm install`
  rewrite `node_modules` while eslint reads it.
- Repro to try: a Node project with `eslint.config.js` importing `@eslint/js`, `fun-ci init`, `fun-ci prune`,
  commit, `fun-ci why <sha>` on lint.
- Workaround used in a downstream project (3d-experiments, `tools/ci/ensure-deps.sh`): both lint and build call
  a script that runs `npm ci` under `lockf` only when a hash of `package-lock.json` differs from a stamp file
  in `node_modules`.

## This repo's own fast suite sits at its 10 s budget

- **Seen** on 2026-10-02: `fun-ci runs` here shows fast OVER BUDGET on 704e31e (a docs-only commit, 10.1 s)
  and twice on 02bfb89, with fast ok on neighbouring commits. Another project's pipeline was running on the
  same machine around 704e31e; whether that contention is the cause is **unverified**.
- `fun-ci why 704e31e fast` shows one `rake fast` process loading every acceptance, policy and unit test
  file, still running at the kill.
- Next step: time `rake fast` cold on an idle machine and under a parallel load, and find which files dominate.
- **Seen again** on 2026-10-05: fast OVER on 7b6d7ca, another docs-only commit. Timed by hand right after on the
  same machine: `rake fast` took 6.24 s on the first run, then 2.86 s and 2.62 s, while the load average was 21 to 28
  on 14 cores (Spotlight's corespotlightd at about 105% CPU, re-indexing after large downloads in another project).
  So the suite fits its budget with room when warm; a cold start under heavy load is what reaches 10 s. Not yet
  measured: the duration of the overrunning run itself, since nothing is kept beyond the kill.
- **Measured** on 2026-10-06: fast went OVER (10.1 s) twice on 61c1810, a docs-only commit, with this repo's slow
  stage alongside both times. Straight after, in the main checkout with slow still running, `rake fast` took 20.69 s
  and then 2.58 s, 1734 runs both times. So the time goes to a cold first run, not to the tests; what the cold run
  spends it on is not measured.

- **Seen** in 3d-experiments on 2026-10-10: fast OVER on 1505d1c (10.1 s) with `alongside: slow` in `fun-ci why`,
  because the post-commit hook started the slow stage of 7ed514c at the same moment. Re-triggered alone
  (`fun-ci trigger 1505d1c main`) it passed: fast ok 7.0 s, lint 5.0 s, build 12.5 s, slow 38.8 s. Timed by hand the
  same hour: vitest unit 5.1 s, rules 1.2 s, the Python tools tests 0.2 s. So the stage fits its budget alone, with
  about 3 s to spare, and the overrun is the concurrent slow stage. The budget does not depend on the commit.
