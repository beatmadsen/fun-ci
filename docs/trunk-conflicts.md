# Trunk conflicts: design

This is a plan, not a description of fun-ci as built. It designs a check that
tells the developer and their agents, on every run, whether the commit would
merge cleanly into the team's trunk. Once it is accepted, its decisions move
into `architecture.md`, what the developer sees into `design.md`, its
requirements into `acceptance-tests.md` as §11, and this file is deleted.

## The problem

fun-ci answers "is this commit fine?" for the commit on its own. In trunk-based
work, or anything close to it, the next question is "will it still be fine
once it meets everyone else's work?", and the first way that goes wrong is a
merge conflict with the trunk (`main`, `master`, `develop`, whatever the team
integrates on). Today the developer finds out when `git pull --rebase` stops
halfway, or when a pull request says it can't be merged, often hours after the
conflicting change landed upstream. An agent finds out even later, because it
never looks.

A conflict found within seconds of the commit that caused it is small and
cheap to resolve. That is the whole point of integrating often, and fun-ci
already runs on every commit, so it is the right place to ask.

## What it answers

A check compares one commit with one trunk SHA and finds:

- **ahead**: commits in the commit's history that the trunk lacks;
- **behind**: commits in the trunk that the commit's history lacks;
- **outcome**: `clean` or `conflicts` (with the files), or `unknown` (with a
  reason) when the check couldn't be made.

What the developer and agents are shown follows from those, and is never
stored:

| Shown as | When |
|---|---|
| `in trunk` | ahead is 0: the trunk already has the commit |
| `up to date` | behind is 0: the commit already has the trunk's tip |
| `clean` | both above 0, and the merge has no conflicts |
| `conflicts` | both above 0, and the merge conflicts in the files named |
| `unknown` | the check couldn't be made; the reason says what to do |
| `checking` | the run has no check yet, and started less than the fetch deadline plus the check budget ago |

A run that has had no check for longer than that shows `unknown` ("the check
never finished"), so a trigger that was killed, or a laptop that slept
mid-check, can't leave a run `checking` for ever.

Every state that depends on the trunk's tip says how old that tip is (see
Keeping the trunk fresh). Past an hour, or when the last fetch failed, it is
marked stale.

A conflict is not a failure. It doesn't change a stage, the run's status, the
verdict of `status` or `wait` (unless an agent asks, with `--trunk`), the
streak, or the header's resting outcome. The code in the commit may be
perfectly good; what is late is its integration. Mixing the two would make a
red row mean either "your tests fail" or "someone else pushed", and the board
would stop being readable at a glance.

## What the developer sees

### The console

A branch whose newest run conflicts with the trunk gets a magenta marker after
its name that names the trunk, set off by the same two spaces as every other
field:

```
> 8d552d0  feat/search  conflicts main  Lint 0.3s  Build 1.2s  Fast 1.8s  Slow ⠁ 9s  RUNNING  just now
  c67191d  main  Lint 0.3s  Build 1.2s  Fast 1.8s  Slow 47s  PASSED  10m ago
```

- Only a conflict is shown on a row. The other states draw nothing, so a board
  where all is well stays a wall of green with nothing added.
- The marker belongs to the branch, not to a run: it is shown on the branch's
  newest run, and it follows the branch's latest **settled** check (`clean`,
  `conflicts`, `up to date` or `in trunk`). A new commit's run that is still
  `checking`, or whose check ended `unknown`, keeps the branch's last settled
  state, so the marker doesn't flicker off and on with every commit.
- Magenta is the one colour the board doesn't use yet, so it can't be taken for
  a failed (red) or timed-out (yellow) stage. The marker sits before the
  stages, so a narrow terminal truncates the row's end, not the marker.
- `conflicts main` is the first candidate. The wording and any glyph are
  settled by comparing candidates in the headless PNGs at 60 columns: the
  marker has to name the trunk and must not read as part of the branch name.
- When a branch's settled state becomes `conflicts`, the header plays a short
  magenta scene from a new pool (`trunk_conflict`): two strands that tangle
  into a knot, a motion no success (a calm rise) or failure (a shake) uses. The
  footer shows `FEAT/SEARCH CONFLICTS WITH MAIN`, fading, as it does for a
  failed stage. When the settled state moves from `conflicts` to any other
  settled state, a second pool (`trunk_clear`) unties the knot. A move to
  `unknown` plays nothing: that would announce good news nobody has.
- Several branches changing in one poll (one trunk move can recheck them all)
  make one scene, not one each, so they can't queue ahead of the scene for the
  commit the developer just made.
- None of this touches the header's resting outcome, the lamp or the streak.
- When a project's trunk is stale (not fetched for an hour, or its last fetch
  failed), the footer adds one dim note, `trunk stale: fun-ci (3h)`, naming
  the projects. Staleness is said once, not on every row, and it is dim so it
  never competes with the colours.

The behind count is not on the board. It changes with every upstream commit,
and a number that moves on rows that are otherwise fine is the kind of noise
the board exists to avoid. It is in the agent commands, where it helps decide
when to integrate.

### The hooks

The post-commit hook is unchanged. The pre-push hook is unchanged too, and it
does not stop a push that conflicts: pushing a conflicting feature branch is a
normal step (sharing work, opening a pull request), and a push to the trunk
that has fallen behind is already refused by the remote as not a fast forward.
What the pre-push hook prints comes from `fun-ci wait`, so the trunk line below
shows up at push time once the check has finished.

### `fun-ci check`, and the first run

`check` names the trunk, where that came from, and how fun-ci keeps it fresh:

```
Trunk: origin/main (origin's default branch). fun-ci fetches it in the background, at most every 5 minutes; set trunk_fetch: false in .fun-ci/config to stop.
```

With no trunk found it warns, naming `trunk:` in `.fun-ci/config`, and exits as
it would without the warning: a project with no remote and no trunk branch
still runs its pipeline. The first run that fetches prints the same sentence
once, so the network access never comes as a surprise.

## What an agent sees

### `status` and `wait`

After the stage lines (and after the digest of a failed stage, when there is
one) comes the trunk line. For a conflict, the files follow, then what to do
and when:

```
fun-ci: 3f9c2ab "Add shipping to the cart total" on feat/cart
  lint   passed         0.6s
  build  passed         0.3s
  fast   passed         0.3s
  slow   running
  trunk  conflicts      origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind
    lib/cart.rb
    lib/total.rb
Conflicts with origin/main in 2 files. When the task is done, integrate: git pull origin main (or git pull --rebase origin main if the branch isn't shared)
fun-ci why 3f9c2ab trunk
```

- The line reads the same way in every state:
  `trunk  clean  origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind`,
  `trunk  up to date  origin/main 9e1d004, fetched 2m ago`,
  `trunk  in trunk`, and
  `trunk  unknown  <reason>`.
- A stale trunk says so where the age is: `fetched 3h ago, STALE`, or
  `fetched 3h ago, STALE (fetch failed: could not resolve host)`. So "up to
  date" or "clean" is never read as more than it is.
- A check still running prints no line, unless `--trunk` asked for it; right
  after a commit (and so at push time) it would say nothing useful.
- A run older than this feature prints no line.
- The next step is built from the resolved trunk, never a hard-coded `origin`:
  - on the trunk branch itself, `git pull --rebase <remote> <branch>`;
  - on another branch, `git pull <remote> <branch>` (a merge), with the
    rebase offered only for an unshared branch, since a rebase of a pushed
    branch needs a force push;
  - with a local trunk and no remote, `git merge <trunk>`.

  The pull fetches first, so it integrates the trunk fun-ci checked or a newer
  one, never an older one.
- It says "when the task is done" because an agent acts on printed commands,
  and an agent that integrates mid-task mixes someone else's changes into work
  it hasn't finished.
- When a needed stage failed, the trunk line is still printed, but without the
  next step. The failure is the agent's to fix first.

The exit codes don't change. They are a published contract, and a conflict is
not a verdict on the commit. An agent that wants to branch on integration asks
with `--trunk`:

- `status --trunk` and `wait --trunk` exit **6** when the verdict would be 0 and
  the commit conflicts with the trunk. `wait --trunk` also waits for the check.
  `status --trunk` exits 3 (undecided) while the check is running.
- A failure still wins: a failed stage exits 1 whatever the trunk says.
- `--trunk` with `unknown` exits with the verdict alone, and the trunk line
  says why it wasn't checked. Every cause of `unknown` (no trunk, unrelated
  histories, an old git, a check over budget) holds for the project, not the
  commit, so an exit code for it would fail every run of that project until
  someone changed the configuration. `0` under `--trunk` means "passed, and no
  known conflict"; the README says that in those words.
- `--trunk` also checks again when the trunk has moved since the run's check
  (below).

`fun-ci init`'s section in `AGENTS.md` gains one sentence: before calling work
done, run `fun-ci wait --need all --trunk`; 6 means the trunk has to be
integrated first, as it prints. Running `init` again still adds nothing, so a
project set up earlier gets the advice from `wait`'s output alone.

### `status --json`

The document gains a `trunk` object, `null` for a run older than this feature.
The schema stays 1, because adding a field breaks no reader and no published
field changes name:

```json
"trunk": {"state": "conflicts", "ref": "origin/main", "sha": "9e1d004...",
          "as_of": "2026-09-29T10:14:03Z", "stale": false,
          "fetch": "ok", "fetch_error": null,
          "ahead": 3, "behind": 4, "files": ["lib/cart.rb", "lib/total.rb"],
          "reason": null, "moved_to": null}
```

- `state` is one of the shown states, spelled `in_trunk`, `up_to_date`,
  `clean`, `conflicts`, `unknown`, `checking`.
- `ahead` counts commits the commit has and the trunk lacks; `behind`, the
  reverse.
- `fetch` is `ok`, `failed` or `off`, with `fetch_error` set when it failed.
- `files` is empty unless the state is `conflicts`; `reason` is set only for
  `unknown`.
- `moved_to` is the trunk's current SHA when it has moved since this check,
  otherwise null.

`runs --json` carries the same object in each run's document. The `events` line
below carries it too, so each name means the same thing everywhere.

### `runs`

`runs` lists history, so each run shows its own check, as of when it was made.
A run that conflicted gets `conflicts origin/main` before the commit subject,
where it can't be read as part of the subject.

### `why REV trunk`

`trunk` is accepted wherever `why` takes a stage name. It merges the run's
commit with the trunk SHA of its check again, which is cheap and gives the
same answer every time, and prints: the trunk ref and SHA and when it was
fetched, ahead and behind, git's own merge messages (`CONFLICT (content): Merge
conflict in lib/cart.rb`, and renames and deletions that clashed), and each
conflicting file's conflicted regions with three lines around each, as a merge
would leave them:

```
lib/cart.rb
  12    def total
  13      subtotal +
  14  <<<<<<< 3f9c2ab
  15      shipping
  16  =======
  17      tax
  18  >>>>>>> origin/main
  19    end
```

This is what an agent needs to resolve the conflict without first running the
merge to see it. `why REV trunk --json` gives the same as one document with
`facts` and `excerpts` in the shape of a stage's evidence, capped by
`Evidence::Caps`. If either commit is gone (the trunk was force-pushed and
gc'd), `why` says so.

### `events`

A new event, `trunk_checked` (`schema` 1, `event`, `commit`, `branch`, and the
`trunk` object), for each check recorded. `--only failures` leaves it out: a
conflict is not a failure. An agent that wants them filters on the event name.

## Which ref is the trunk

In order, the first that exists:

1. `trunk:` in the project's `.fun-ci/config` (the checkout's, as
   `worktree_slots` is, not the commit's as `evidence:` is: one project has one
   trunk, whichever branch a run is on). Any name `git rev-parse` accepts
   (`origin/develop`, `upstream/main`, `main`), or `none` to turn the check off.
2. The remote's default branch: `refs/remotes/<remote>/HEAD`, which `git clone`
   sets. `<remote>` is `origin`, or the only remote there is.
3. The first of `<remote>/main`, `master`, `develop`, `development`, `trunk`.
4. With no remote, the first local branch of those names.

Otherwise the state is `unknown` ("no trunk found; set trunk: in
.fun-ci/config"). `init` writes nothing for it, in the same spirit as the
presets: a list written at init goes stale when the team renames its trunk.

Commits made on the trunk branch itself are checked the same way. For a
developer committing to `main` and pushing, "conflicts with origin/main" means
their `git pull --rebase` is likely to stop on those files (a rebase replays
commit by commit, so it can stop where the merge of the tips doesn't, and the
reverse; see Decisions).

## How the check works

```
git rev-list --left-right --count <commit>...<trunk>
git merge-tree --write-tree --name-only --messages <commit> <trunk>
```

- The first gives ahead and behind. When either is 0 there is nothing to merge
  and the check stops there.
- The second: exit 0 is `clean`; exit 1 is `conflicts`, with the conflicted
  paths after the merged tree's SHA and the messages after a blank line;
  anything else is `unknown` with a reason written for the reader, for
  instance "origin/main shares no history with this commit; set trunk: in
  .fun-ci/config" (git exits 128 on unrelated histories).
- `why` adds `git cat-file --batch` for the conflicted files of the merged
  tree, one process for all of them.

It needs no worktree and no slot. `merge-tree` merges in memory against the
object database the worktrees share, so the check runs beside lint and build
without touching the checkout they run in and without waiting for a free slot.

`merge-tree --write-tree` writes the merged tree and the conflicted blobs into
the repository's object store (measured below: two new objects for one small
conflict). They are unreachable and `git gc` would remove them in time, but a
check on every commit shouldn't leave anything behind. So fun-ci runs it with
`GIT_OBJECT_DIRECTORY` pointed at a scratch directory in the state directory
and `GIT_ALTERNATE_OBJECT_DIRECTORIES` at the repository's own objects, and
deletes the scratch directory afterwards.

A git older than 2.38, whose release notes add the `merge-tree` mode that
"takes two commits and computes a tree that would result in the merge commit",
gives `unknown` ("needs git 2.38 or later; this is 2.34.1"). fun-ci finds out by
running it and reading the usage error, then names the version `git --version`
reports.

The check has a budget, 5 seconds by default. A large repository with rename
detection can take a while, and a check that runs over is killed with its
process group and shown as `unknown` ("over its 5 s budget; raise
trunk_budget, or set trunk: none").

## Keeping the trunk fresh

A merge check against a trunk last fetched yesterday says little, and most
developers don't fetch often. So when the trunk is a remote's branch, fun-ci
fetches it itself:

```
git fetch --quiet --no-tags --no-write-fetch-head --no-recurse-submodules \
  --no-auto-maintenance --refmap= <remote> +refs/heads/<branch>:refs/fun-ci/trunk/<remote>/<branch>
```

- It fetches into a ref of fun-ci's own, `refs/fun-ci/trunk/...`, never into
  `refs/remotes/`. Updating the developer's remote-tracking ref would change
  what `git status` says under them, and would race their own `git fetch` or
  `git pull` for the ref's lock, which can make theirs fail.
- `--refmap=` (empty) is required. Without it git updates
  `refs/remotes/origin/main` as well, as a side effect of any fetch that names
  a refspec (measured below). With it, only fun-ci's ref moves.
- `--no-auto-maintenance` stops the fetch from starting a gc that the deadline
  would then kill halfway, leaving a lock behind.
- Nothing may ask the developer anything: `GIT_TERMINAL_PROMPT=0`,
  `SSH_ASKPASS_REQUIRE=never`, `GCM_INTERACTIVE=never` (Git Credential
  Manager's switch [unverified]), and, unless the developer has set their own
  ssh command (`GIT_SSH_COMMAND` or `core.sshCommand`), which fun-ci leaves
  alone, `GIT_SSH_COMMAND="ssh -o BatchMode=yes"`. A fetch that would have
  prompted fails at once instead.
- A confirmation that the SSH agent asks for itself (`ssh-add -c`, a hardware
  key's touch, a password manager's approval) is outside ssh's options and can
  still appear [unverified]. So fetches are rare (at most every 5 minutes per
  project by default, `trunk_fetch: 10m` to change it), back off after a
  failure (doubling up to an hour), and are announced (above) with the setting
  that stops them.
- The fetch has a deadline of 20 seconds, after which its process group is
  killed. The group is recorded in `Persistence::ActiveRuns` like a stage's,
  so cancelling the run kills the fetch too.
- The interval is claimed atomically: one `UPDATE trunk_fetches SET claimed_at
  = ? WHERE project_path = ? AND claimed_at < ?`, and only the process whose
  update changed a row fetches. Two hooks at once make one fetch, and the other
  doesn't record a false failure from losing the ref's lock.
- A failed fetch never fails anything. The check goes ahead against the newest
  trunk fun-ci has, and the output says how old it is and why the fetch
  failed.

Which ref the check reads is then simple. With fetching on, fun-ci's own ref
(the remote-tracking ref only until fun-ci's first fetch has made it). With
`trunk_fetch: false`, the remote-tracking ref, whose "as of" is when it last
moved, from its reflog, or `unknown` when it has none.

Fetching is on by default. That is a judgment call: fun-ci is local-first, and
this is the first thing it does over the network. The case for it is that
without a fresh trunk the check reports stale news with a straight face, and
the fetch touches nothing of the developer's.

## When it runs, and when it runs again

A check is a fact about a pair: this commit against that trunk SHA. It never
goes stale for that pair; it goes stale when the trunk moves. So a check is
written once and never changed, and fun-ci makes a new one when the trunk has
moved:

- **Each trigger** fetches the trunk and checks its own commit. If the trunk
  SHA changed, it also checks the newest run of each other branch of the
  project, among the runs retention keeps (the project's 50 newest), whose
  latest check is against another trunk SHA. So one commit on any branch
  refreshes every branch the board shows. Each check is one `merge-tree`,
  about 10 ms on this repository.
- **`--trunk`** on `status` or `wait` checks the commit again when the trunk
  ref, read locally without a fetch, has moved since the run's check.
- **Everything else only reads**: `status` and `wait` without `--trunk`,
  `runs`, `events`, the console. When the trunk has moved since a check they
  say so (`origin/main has moved to 1a2b3c4 since`, and `moved_to` in the
  JSON), but they don't check again, so reading never runs merges and `runs`
  never runs one per line.

The trunk can move while nobody commits, and then the board shows the last
check until the next commit or `--trunk`. For someone committing every few
minutes that gap is small. If it turns out not to be, the fix is a timer in the
console loop that runs a trigger's fetch and recheck without a commit, which
would be the console's first git call.

### Inside the trigger

`Trigger#run` starts the fetch and check in a thread before `run_in`, keeps it
in a local variable, and joins it after `run_in` returns, on the early return
when lint or build fails as well. The thread does no database work: it returns
a result, which `Trigger` records through the recorder it holds after
`run_in`, the one `BackgroundFork` swapped in once the slow suite forked. A
thread writing through the recorder it started with could find it closed.

So a run's check is recorded after its fast suite, not when it finishes. That
is at most the fast suite's 10 s budget late, and it keeps every write on the
one connection the trigger's process owns. The thread isn't in `SlotRun`,
since the check needs no slot.

## Storage

A new table, written once per pair and never updated:

```sql
CREATE TABLE IF NOT EXISTS trunk_checks (
  id INTEGER PRIMARY KEY,
  project_path TEXT, commit_hash TEXT, trunk_ref TEXT, trunk_sha TEXT,
  trunk_seen_at TEXT, checked_at TEXT,
  outcome TEXT, ahead INTEGER, behind INTEGER, files TEXT, reason TEXT,
  UNIQUE (project_path, commit_hash, trunk_sha)
)
```

- Two processes checking the same pair at once compute the same answer, and
  `INSERT OR IGNORE` keeps the first. No write ever needs to know which trunk
  SHA is newer, which SQL can't tell anyway: commit IDs have no order, and
  after a force push "older" means nothing.
- `trunk_seen_at` is when fun-ci first saw that trunk SHA (its fetch time, or
  the reflog's). A commit's current check is its row with the latest
  `trunk_seen_at`; a run's own check, for `runs`, is its commit's latest row
  checked before the next run of its branch.
- Retention deletes rows whose commit has no run left.

And one for fetching, per project: `trunk_fetches (project_path TEXT PRIMARY
KEY, ref TEXT, sha TEXT, claimed_at TEXT, fetched_at TEXT, failures INTEGER,
error TEXT)`, for the interval, the back-off and the "as of".

Nothing of `why REV trunk` is stored. Merging again is cheap and gives the same
answer, so there is no evidence to cap, mask or prune.

## The renderer protocol

- A run in `board` may carry `"trunk": {"branch_state": "conflicts", "trunk":
  "main"}`. Ruby sends it only on the runs that should show the marker (the
  newest run of its branch in its project, whose branch's settled state is
  `conflicts`), so the renderer decides nothing about which rows qualify.
- `board` may carry `"stale_trunks": [{"project": "...", "since": <epoch>}]`
  for the footer's note.
- The protocol ignores unknown fields, so neither needs a new protocol version.
- Two event names, `trunk_conflict` and `trunk_clear`, with `run_id` of one
  branch's newest run and `branches` (how many changed in that poll). Ruby
  sends at most one of each per poll, after the stage and milestone events of
  the same poll. A `TrunkChangeDetector`, keyed on project and branch, decides
  them from the branches' settled states, the way `StageChangeDetector` decides
  stage events.
- A new contract fixture holds a conversation with both events, and a new
  scenario in `contract/scenarios/` pins the row, the footer and the two
  scenes as reviewed snapshots.

## Where the code goes

A new `lib/fun_ci/trunk/`, each piece small enough for the code limits:

- `Resolver`: which ref is the trunk, from the settings and a list of the
  repository's refs.
- `Fetch`: the fetch into fun-ci's ref, its environment, deadline, interval
  claim and back-off.
- `MergeCheck`: the two git commands in a scratch object directory, returning
  a `Check` (ahead, behind, outcome, files, reason).
- `Shown`: the state shown for a run from its checks, its start time and the
  clock (`checking`, `unknown` after the deadline, `in trunk`, ...), and the
  branch's settled state.
- `Regions`: the conflicted regions of a file with their context, for `why`.
- `Recheck`: which branches' newest runs to check again once the trunk has
  moved.
- `TrunkText`, `TrunkJson`: the trunk line, the next step and the object for
  `status`, `wait`, `runs`, `why` and `events`.

`Pipeline::Seams` gains `trunk`: what fetches and checks, `nil` for the real
thing. Its deadline and budget come in through `time_budgets`, like the
stages', so a test can set them to what it needs. Unit and acceptance tests
pass a fake that returns a scripted `Check`, so they run no git. The real git
work is tested in `test/integration/process/` against temporary repositories
with a bare repository as the remote, per the spawn rules in `CLAUDE.md`; a
remote that never answers is an ssh command that blocks reading a FIFO the
test holds, released by the kill.

## Decisions

**Decision: a check is a fact about the run's commit, not a stage.** A fifth
stage (`.fun-ci/integrate.sh`) would reuse the stage rows, but a stage has a
script, a pass or fail that settles the run's status, and a place in the
verdict. A conflict would then fail the run, break the streak and set off the
explosion for something the commit's author may not have caused yet.
*Revisit if* teams ask to hold their commits to "integrates cleanly" as
strictly as to "passes the fast suite". Then `--trunk` becomes a level of
`--need`.

**Decision: checks are rows written once per pair.** Columns on
`pipeline_runs` overwritten by each recheck would need a guard against a slow
check overwriting a fresher one, which needs an order of trunk SHAs that
doesn't exist, and would rewrite the history `runs` shows.

**Decision: merge-tree in memory, not a merge in a worktree.** A
`git merge --no-commit` in a slot would need the slot for its duration, and
reset it afterwards, while lint and build want it. `merge-tree` needs neither
and took about 10 ms here.

**Decision: a three-way merge, not a rebase.** A rebase replays the branch
commit by commit and can stop on a conflict in an intermediate commit even when
the merge of the tips is clean; the reverse can happen too. Checking the tips
answers "does the result conflict?" with one call. Replaying each commit costs
a merge per commit, and `git replay`, which would do it in memory, is marked
"THIS COMMAND IS EXPERIMENTAL. THE BEHAVIOR MAY CHANGE." in git's
documentation.
*Revisit if* developers hit rebase conflicts the check called clean.

**Decision: fetch into fun-ci's own ref, with an empty refmap.** Both measured
below. *Revisit if* a hosting setup refuses fetches of an explicit refspec.

**Decision: no exit code for `unknown` under `--trunk`.** Its causes belong to
the project, so a separate code would fail every run until someone changed the
configuration, and an agent can't fix an old git or a missing trunk from
inside its task. The trunk line says why the check wasn't made.

**Decision: don't notice fetches with a `reference-transaction` hook.** It
would let fun-ci check again the moment the developer fetches. Measured below,
it runs twice for every ref git updates, including `HEAD` on every checkout,
so it would put a process start on the path of ordinary git commands, and it
is a third hook for `install-hooks` to own.

**Decision: textual conflicts only.** A clean merge can still break the build:
one side renames a method the other side calls. `merge-tree` already produces
the merged tree, so a natural next step is to run the fast suite on it
(`git commit-tree` gives it a commit a slot can check out). That is a second
pipeline per commit and a separate design.

## Acceptance tests (proposed §11)

Built in the order of their numbers, one behaviour each. "Process" marks those
in `test/integration/process/`, in a temporary repository whose remote is a
bare repository in the same temp root; the rest use the fake trunk seam and
run no git.

**The check**

- **11.1** (process) A commit whose branch and the remote's trunk have both
  moved on, touching different lines, is recorded `clean` with its ahead and
  behind. *Bites:* nothing looks at the trunk today.
- **11.2** (process) The same, touching the same lines, is recorded
  `conflicts` with the files.
- **11.3** A check with behind 0 shows `up to date`, and one with ahead 0 shows
  `in trunk`.
- **11.4** (process) A trunk with no history in common is `unknown`, with the
  reason naming `trunk:`.
- **11.5** (process) A check over its budget is killed and shown `unknown`,
  naming `trunk_budget` and `trunk: none`.
- **11.6** A git without `merge-tree --write-tree` gives `unknown` naming 2.38
  and the version installed.
- **11.7** (process) The check leaves `git count-objects` as it was, and moves
  no ref outside `refs/fun-ci/`.
- **11.8** `trunk: none` makes no check and prints no trunk line.

**Which trunk**

- **11.9** `Resolver`, over a list of refs, picks `trunk:`, then
  `<remote>/HEAD`, then `main`, `master`, `develop`, `development`, `trunk` on
  the remote, then locally, and `unknown` with none.
- **11.10** (process) Real refs resolve the same: a clone's `origin/HEAD`, and
  a repository with no remote and a local `develop`.

**Fetching**

- **11.11** (process) A run fetches the remote's newer `main` into
  `refs/fun-ci/trunk/origin/main` and checks against it. *Bites:* without
  `--refmap=` the next test fails.
- **11.12** (process) That fetch leaves `refs/remotes/origin/main` and
  `FETCH_HEAD` as they were.
- **11.13** A second run within the interval doesn't fetch.
- **11.14** (process) Two triggers at once make one fetch, and neither records
  a failure.
- **11.15** With `trunk_fetch: false` nothing is fetched, and the "as of" comes
  from the remote-tracking ref's reflog.
- **11.16** (process) An unreachable remote records `fetch` `failed` with the
  error, and the stages are recorded as they would be.
- **11.17** (process) A remote that never answers is killed at the fetch
  deadline (set short by the test).
- **11.18** After a failed fetch the next is put off, doubling to an hour.
- **11.19** (process) Cancelling a run mid-fetch kills the fetch's process
  group.
- **11.20** The first fetch of a project prints the sentence `check` prints,
  once.

**In the pipeline**

- **11.21** A conflict leaves the run `completed` when its stages pass,
  counting towards the streak.
- **11.22** A run whose lint fails still records its check.
- **11.23** (process) A run whose slow suite forks while the check runs records
  the check once and writes nothing to stderr.
- **11.24** A run with no check past the fetch deadline plus the check budget
  shows `unknown`, "the check never finished".

**Rechecks**

- **11.25** A trigger that fetches a new trunk SHA checks the newest run of
  each other branch whose latest check is against another.
- **11.26** `status --trunk` checks again when the trunk ref has moved;
  `status` without it prints `has moved to <sha> since` and checks nothing.
- **11.27** Two processes recording the same pair keep one row.

**Agent output**

- **11.28** `status` prints the trunk line of each state, with the age and
  `STALE` past an hour or after a failed fetch.
- **11.29** A conflict prints the files and the next step for its case: the
  trunk branch (`pull --rebase`), another branch (`pull`, rebase offered), a
  local trunk (`merge`), each naming the resolved remote and branch.
- **11.30** When a needed stage failed, the digest comes first and the trunk
  line has no next step.
- **11.31** A check still running prints no trunk line without `--trunk`.
- **11.32** `status --trunk` exits 6 for a passed run that conflicts.
- **11.33** `status --trunk` exits 1 for a failed run that conflicts.
- **11.34** `status --trunk` exits with the verdict alone when the trunk is
  `unknown`.
- **11.35** `status --trunk` exits 3 while the check runs, and `wait --trunk`
  returns once it finishes.
- **11.36** `status --json` carries the `trunk` object with every field, `null`
  for a run older than this feature, and `schema` 1.
- **11.37** `runs` shows each run's own check, before its subject.
- **11.38** `why REV trunk` prints the trunk, the merge messages and the
  conflicted regions with three lines around each; `--json` the same as one
  document.
- **11.39** `events` prints `trunk_checked` for each check recorded, and
  `--only failures` leaves it out.
- **11.40** `init`'s `AGENTS.md` section names `wait --need all --trunk` and
  exit 6.
- **11.41** `check` names the trunk, where it came from and how it is fetched,
  and warns naming `trunk:` when there is none, exiting as it would without the
  warning.

**The console**

- **11.42** `board` carries the marker on a branch's newest run when the
  branch's settled state is `conflicts`, and on no older run.
- **11.43** A new run that is `checking` or `unknown` keeps its branch's
  marker.
- **11.44** A branch whose settled state becomes `conflicts` sends one
  `trunk_conflict`; becoming settled otherwise sends `trunk_clear`; becoming
  `unknown` sends nothing.
- **11.45** Three branches changing in one poll send one event of each kind.
- **11.46** `board` names the projects whose trunk is stale.
- **11.47** (contract fixture) The renderer accepts both events and the new
  fields.
- **11.48** (snapshot) The renderer draws the marker in magenta before the
  stages, at 60 columns too, the stale note in the footer, and a scene from
  each new pool, without changing the resting outcome, the lamp or the streak.

## Measurements

What this design rests on, measured with git 2.53.0 and OpenSSH 10.3p1 on
macOS in a scratch repository, and on this repository for the timing:

- `git merge-tree --write-tree` exits 0 for a clean merge and 1 for a
  conflict, and prints the merged tree's SHA first; with `--name-only` the
  conflicted paths follow, and with messages on, lines such as
  `CONFLICT (content): Merge conflict in f.txt` follow a blank line. Unrelated
  histories exit 128 with `fatal: refusing to merge unrelated histories`.
- `git cat-file -p <tree>:f.txt` on that tree gives the file with conflict
  markers, labelled with the names given to `merge-tree`.
- One conflicted merge-tree added two objects (the merged tree and the
  conflicted blob) to the repository's object store (`git count-objects`, 29
  before, 31 after). With `GIT_OBJECT_DIRECTORY` at a scratch directory and
  `GIT_ALTERNATE_OBJECT_DIRECTORIES` at the repository's objects, the count
  stayed the same (37 before and after), the scratch directory gained two
  objects, and the merged blob could be read through the same variables and
  not without them.
- `git merge-tree --write-tree --name-only HEAD~40 HEAD` on this repository
  took 0.010 s.
- A fetch of `+refs/heads/main:refs/fun-ci/trunk/origin/main` also moved
  `refs/remotes/origin/main`; the same fetch with `--refmap=` moved only
  `refs/fun-ci/trunk/origin/main`. `--no-write-fetch-head` left no
  `FETCH_HEAD`. `git fetch -h` lists `--[no-]auto-maintenance` and `--refmap`.
- `man ssh` documents `SSH_ASKPASS_REQUIRE=never` ("ssh will never attempt to
  use one").
- A `reference-transaction` hook ran for one `git update-ref` and one
  `git checkout` and logged 20 lines: a `prepared` and a `committed` call for
  each transaction, the checkout's including `HEAD`.
- `git clone` set `refs/remotes/origin/HEAD` to the branch checked out in the
  source repository at the time, which need not be the trunk. Resolution step 2
  trusts it anyway because on hosted remotes it is the default branch the team
  chose; `trunk:` overrides it where that is wrong.
- Read, not measured: git 2.38's release notes say `merge-tree` "learned a new
  mode where it takes two commits and computes a tree that would result in the
  merge commit"; git's `git-replay` page says "THIS COMMAND IS EXPERIMENTAL.
  THE BEHAVIOR MAY CHANGE."

Not measured: how long `merge-tree` takes on a repository with hundreds of
thousands of files, which is what the 5 s budget guards against; whether
`GCM_INTERACTIVE=never` stops Git Credential Manager's windows; and whether an
SSH agent's own confirmations appear under `BatchMode=yes`.

## For the owner to settle

These are judgment calls this design makes; each is easy to reverse before
building:

1. Fetching the trunk over the network by default, in a tool that has been
   local-only so far, with the risk that an SSH agent asks for approval on
   each fetch (about every 5 minutes while committing).
2. Not stopping a push that conflicts.
3. `--trunk` and exit code 6 as the way an agent opts in, rather than a new
   `--need` level, and `init` teaching agents to use it before calling work
   done.
4. The magenta `conflicts main` marker, the footer note for a stale trunk, and
   two new header pools.
