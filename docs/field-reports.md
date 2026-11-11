# Field reports

**Document type:** an inbox of problems seen while using fun-ci in other projects.
Each entry says what was observed, how to reproduce it, and whether it was seen or inferred.
An agent picking one up fixes it under the repo's usual discipline (failing test first), then deletes the entry.

---

## The slow stage starves when several agents commit to one branch, and `--follow-branch` waits never end

**Seen** in project-studio on 2026-10-21 (fun-ci 2.4.0), measured from `fun-ci runs -n 400 --json` against each commit's time in `git log`.

- From 15:00 to 23:00 the branch took 242 commits: up to three agents committing code, plus an orchestrator committing records. 175 of those runs had their slow stage cancelled by a newer commit (72%); 55 passed and 8 failed.
- The slow stage takes 241 to 251 s. Commits landed every one to three minutes, so a slow run seldom finished. The longest gaps between commits whose slow run finished were 32.5, 21.5, 17.4 and 16.6 minutes.
- Every agent waited with `fun-ci wait HASH --need all --follow-branch`, the command the post-commit hook prints. Each newer commit cancelled the run it waited on and moved the wait on, so one agent's wait ran from 22:53 to 23:01:43 through four cancelled slow runs. Agents sat idle for 15 to 30 minutes after their work was committed, which looked like agents failing to wake from a background wait. It was the wait not ending.
- Commits that changed only data files no stage reads differently (`studio/*.json`) cancelled code commits' slow runs the same as code commits did.

**Reproduce:** a project whose slow stage takes about 4 minutes; commit to one branch every 1 to 2 minutes; wait on the first commit with `fun-ci wait --need all --follow-branch`. The wait does not return until the commits stop for one slow run's length.

**What helps today (README, line 54):** a run an agent waits on without `--follow-branch` is not cancelled, once the wait has polled it; see the next entry for the gap before that. project-studio has its agents wait that way, start the wait straight after the commit, and trigger the commit again on exit 4.

**For fun-ci to consider (inferred, not tried):**
- Let a slow stage that is already running finish, and when it does, run only the newest of the commits that arrived meanwhile, instead of cancelling on every commit.
- Or decide the verdict for a superseded commit when a later run on a descendant passes, so `--follow-branch` waits end as soon as any run finishes.
- The post-commit hook prints `--follow-branch`, and the `AGENTS.md` section `fun-ci init` writes says "A newer commit on the branch cancels the run and the wait moves on". Both steer a project with several agents straight into this mode, while the README's way out sits in a long paragraph about worktrees.

## A wait without `--follow-branch` protects its run only after its first poll, and then answers "superseded" for good

**Seen** in project-studio on 2026-10-21/22: commit 678764c had two runs, both `superseded` (by 4fe3f07 and 030c00d, `fun-ci runs --json`), while the agent that made it waited on it with `fun-ci wait 678764c --need all`, no `--follow-branch`.

**Read in the code:** `StalePipelineCanceller` skips a run only when its `waited_at` is within `WAITED_ON_SECONDS` (10 s), and `WaitCommand#poll` sets `waited_at` on each poll. A newer commit that lands between the commit and the wait's first poll (the agent recording its intent, running a local lane) cancels the run. The wait then reports `superseded`, exit 4, and since it does not follow the branch, the commit the agent asked about never gets a verdict unless someone runs `fun-ci trigger` by hand.

**Inferred, not tried:** have a wait without `--follow-branch` whose run was superseded start the commit's run again and keep waiting, since the agent asked for that commit and no other. (The README's sentence read as a guarantee, "unless an agent is waiting on it"; it now says the wait has to be watching the run already, and that a late one exits 4.)

**Reproduce:** commit A; commit B before running `fun-ci wait A --need all`; the wait exits 4.
