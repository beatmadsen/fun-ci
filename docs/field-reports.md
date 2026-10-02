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
