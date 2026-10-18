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

## A cancelled slow stage leaves Playwright's web server running, and the next run fails on its port

- **Seen** with fun-ci 2.3.0 on 2026-10-05 in 3d-experiments. Commit de7e59d's slow stage was cancelled after 13.9 s when
  8d66efc superseded it. 8d66efc's slow stage then failed in 0.5 s: "http://localhost:4357 is already used, make sure
  that nothing is running on the port/url or set reuseExistingServer:true in config.webServer". The listener was
  `npm exec vite preview --port 4357 --strictPort` (PID 89839, PPID 1, process group 89839) with its child
  `node .git/fun-ci/worktrees/slot-0/node_modules/.bin/vite preview`, left from the cancelled run. Killing that group
  and running `fun-ci trigger 8d66efc… main` passed all four stages.
- **Cause, seen in code** (no test yet): `RunCanceller#stop` sends only KILL to the run's processes and stage groups
  (`run_canceller.rb`, `kill`); `ProcessRunner#kill_process_group` sends TERM then KILL with no pause between them
  (`process_runner.rb`, `kill_process_group`). Playwright's `launchProcess` spawns the web server with
  `detached: true` on non-Windows platforms, so the server leads its own process group, and only Playwright's own
  teardown kills that group. A KILL to the stage's group never reaches the server's group and gives Playwright no
  time to tear it down.
- Repro sketch (inferred, not run): a `slow.sh` that starts a grandchild in its own group and waits, such as
  `perl -e 'if (fork) { wait } else { setpgrp(0,0); exec "sleep", "300" }'`; commit twice in quick succession so
  the first run is superseded; `pgrep -f "sleep 300"` still finds the grandchild afterwards.
- Possible fixes: TERM, a short grace period, then KILL, so a stage's own cleanup runs; or kill every process group
  in the stage's session. Not a fix: `reuseExistingServer: true`, which would let a later run test an earlier
  commit's build.
- **Seen again** with fun-ci 2.3.0 on 2026-10-06 in 3d-experiments: 4c25788's slow stage was cancelled after 28.1 s
  when 995596a superseded it, and 995596a's slow stage failed after 9.3 s on the same port 4357. The orphan was
  `npm exec vite preview --port 4357 --strictPort` (PPID 1, its own process group) and its `node` child. Killing
  that group and `fun-ci trigger` passed all four stages.
- Correction to the second possible fix: Node's `detached: true` makes the child the leader of a new session as well
  as a new process group (measured: `os.getsid` of a detached `sleep` is its own pid), so killing every group in the
  stage's session would still miss Playwright's web server. A grace period after TERM, or killing the stage's process
  tree by parent id taken before the kill, would reach it.
- 3d-experiments no longer shows it (0f53605): its preview now exits when its stdin, a pipe from Playwright, ends.
  A scratch run that SIGKILLs an `npx playwright test` process group left the old preview listening 3 s later and
  the new one gone. The cancel path itself is unchanged, so any other detached grandchild still outlives a cancel.

## A run that lands in a cold second worktree fails a build budget a warm worktree meets

- **Seen** with fun-ci 2.3.0 on 2026-10-06 in 3d-experiments. Commit 1e8ce32 was still in
  its slow stage in `slot-0` when 6af6ee1 was committed, so 6af6ee1's run took `slot-1`. Its build stage ran over its
  30 s budget (30.1 s): `.git/fun-ci/worktrees/slot-1/public/assets/.inputs` did not exist, so the project's asset
  build, which skips Blender while that stamp matches its sources, rebuilt every asset (`blender/assets/hero.py` had
  run 23 s at the kill). `slot-0` has the stamp and the same stage takes about 4 s there; the next commit, e75d4fd,
  ran in `slot-0` and passed.
- **Cause**: per-slot caches that a project keeps in its worktree (here a generated `public/assets` and its stamp)
  are only as warm as the last run in that slot, and a slot used rarely (only when runs overlap) stays cold for
  days. The budget is sized for the warm case.
- **Possible fixes**: warm a new or stale slot before timing it (a project hook, or the first run in a slot exempt
  from budgets); or share git-ignored build outputs between slots. Not a fix: raising the build budget, which would
  hide a real slowdown in the warm case.

## Worktrees under .git/ trip Vite's default fs.deny for tests in a browser-like environment

- **Seen** with fun-ci on 2026-10-07 in 3d-experiments. Commit 6e43fea's fast stage failed in
  `.git/fun-ci/worktrees/slot-0`: the three Vitest unit files carrying `// @vitest-environment happy-dom` failed with
  `Cannot find module '/test/unit/ui/world/log/log.test.js'` (0 tests), while the same command passed in the main
  checkout. Re-running there with a config whose `server.fs.deny` was emptied passed (8 tests), so the cause is
  Vite's default deny list, which contains `**/.git/**`: web-mode environments load test modules through the Vite
  server's file check, and every path in a worktree under `.git/` matches. Node-environment tests are unaffected.
- **Worked around** in 3d-experiments (afbf5f5): under `VITEST` its vite.config.js denies the other defaults but not
  `.git`. Any other project with jsdom or happy-dom tests will hit the same failure in fun-ci and nowhere else.
- **Possible fix**: keep slot worktrees outside `.git/` (for example under a cache directory beside the repository),
  so tools that treat `.git/` as private do not refuse the checkout.

## Runs of other branches leave their git-ignored build outputs in the shared slot, failing the trunk's next run

- **Seen** with fun-ci on 2026-10-15 in 3d-experiments, three times in one night of agents committing in git worktrees
  (each commit's post-commit hook runs fun-ci in the one `slot-0`). The project's build stage writes git-ignored
  outputs into the slot (`public/assets`: models, compressed in place by one branch's new step), and nothing removes
  outputs a later commit does not make. So: a branch that added meshopt compression left compressed models that the
  trunk's next run (without the decoder) failed on (hero-rig tests, 483f71a); a branch made before that compression
  failed on them the other way (2e22e4a); and a branch that added five yard models left them in the slot, so the
  trunk's `has limits for the slot of every delivered model` failed (f71f9dc). Each passed in its own checkout and
  again once the branches met on the trunk.
- **Cause**: a slot's git-ignored state is shared across branches and is only as right as the last run's commit;
  per-commit determinism holds only for tracked files.
- **Possible fixes**: a slot per branch (or per worktree that triggered the run); or clean git-ignored outputs a
  project names (a `clean` list in `.fun-ci/config`) before each build; or stamp a slot with the commit whose outputs it
  holds and rebuild from scratch when the new commit is not a descendant of it. Not a fix: making the project's
  tests tolerate stray files.
