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
