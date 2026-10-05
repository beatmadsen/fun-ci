# Field reports

**Document type:** an inbox of problems seen while using fun-ci in other projects.
Each entry says what was observed, how to reproduce it, and whether it was seen or inferred.
An agent picking one up fixes it under the repo's usual discipline (failing test first), then deletes the entry.

---

## `fun-ci init --help` runs init instead of printing help

- **Seen** with fun-ci 2.3.0 in an empty project (two markdown files, no code).
- Repro: `mkdir /tmp/x && cd /tmp/x && git init && fun-ci init --help`
- Got: `Could not detect project type. Create .fun-ci/ manually.` (exit 1). Expected: init's usage and options.

## No route for a project whose stack is not detected yet

- **Seen** with fun-ci 2.3.0: in a brand-new repo with no code yet, `fun-ci init` stops with
  `Could not detect project type. Create .fun-ci/ manually.` and writes nothing, so the user has to know the
  four script names and their contract to start.
- Idea: write four placeholder scripts that pass (and say so in `fun-ci check`), or accept `--stack NAME`.

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

## A run started by the post-commit hook dies with the shell that committed, and is reported as a plain failure

- **Seen and reproduced** with fun-ci 2.3.0 on 2026-10-02. In 3d-experiments, an agent's `git commit && fun-ci wait`
  command was interrupted by the user; the slow stage of that commit showed `slow FAIL` with nothing kept
  (`fun-ci why <sha> slow` printed only "slow failed after 12.7s"; `--raw` said no raw output is kept). The
  `stage_jobs` row had `status=failed` with `exit_status`, `signal` and `output_tail` all NULL. Re-triggering the
  same commit passed.
- Repro (about 30 s):

      R=$(mktemp -d) && cd $R && git init -q -b main && mkdir .fun-ci
      for s in lint build fast; do printf '#!/bin/sh\nexit 0\n' > .fun-ci/$s.sh; done
      printf '#!/bin/sh\nsleep 20\n' > .fun-ci/slow.sh && chmod +x .fun-ci/*.sh
      fun-ci install-hooks && git add -A && git commit -q -m base
      echo x >> f && git add f
      perl -e 'setpgrp(0,0); exec @ARGV' sh -c 'git commit -q -m victim; sleep 60' & PID=$!
      sleep 6; kill -TERM -- -$PID; sleep 2; fun-ci runs | head -1    # slow FAIL, no evidence

- Two problems: (1) the pipeline the hook starts stays in the committer's process group, so Ctrl-C in a terminal
  or an agent harness cancelling a command kills the CI run; detaching it (new session/process group) would
  match the README's "starts the pipeline in the background and returns at once". (2) A stage whose runner died
  is reported as a failure of the code, with no hint that it was interrupted; `why` could say so.

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
