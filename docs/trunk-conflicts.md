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

For each run, fun-ci records how the run's commit stands against the trunk as
fun-ci last saw it. There are six states:

| State | Meaning |
|---|---|
| `checking` | The run has started and the check hasn't finished |
| `in_trunk` | The trunk already contains the commit; there is nothing to integrate |
| `up_to_date` | The commit already contains the trunk's tip; it would fast-forward |
| `clean` | The two have diverged and a three-way merge has no conflicts |
| `conflicts` | The two have diverged and the merge conflicts, in the files named |
| `unknown` | The check couldn't be made; a reason says why |

Alongside the state it keeps the trunk ref and SHA it checked against, when
that SHA was fetched (the "as of"), and how many commits the commit is ahead of
and behind the trunk. Being 40 commits behind is worth seeing even when the
merge is clean.

A conflict is not a failure. It doesn't change a stage, the run's status, the
verdict of `status` or `wait`, the streak, or the header's resting outcome. The
code in the commit may be perfectly good; what is late is its integration.
Mixing the two would make a red row mean either "your tests fail" or "someone
else pushed", and the board would stop being readable at a glance.

## What the developer sees

### The console

The row of a branch's newest run gets one word after the branch name, in bold
magenta, when that run conflicts with the trunk:

```
> 8d552d0  feat/search conflict  Lint 0.3s  Build 1.2s  Fast 1.8s  Slow ⠁ 9s  RUNNING  just now
  c67191d  main  Lint 0.3s  Build 1.2s  Fast 1.8s  Slow 47s  PASSED  10m ago
```

- Only a conflict is shown. `clean`, `up_to_date`, `in_trunk` and `unknown`
  draw nothing, so a board where all is well stays a wall of green with nothing
  added.
- Only the newest run of each branch (per project) shows it. An older run's
  conflict is history: the branch has moved on, and a column of magenta down
  the board would be noise.
- Magenta is the one colour the board doesn't use yet, so it can't be taken for
  a failed (red) or timed-out (yellow) stage. The word sits right after the
  branch, before the stages, so a narrow terminal truncates the row's end, not
  the word. The word itself ("conflict") is a first proposal; the glyph and the
  wording are a matter of taste, settled by looking at candidates in the
  headless PNGs.
- The header plays a short scene when a branch's newest run goes from not
  conflicting to conflicting (`trunk_conflict`), and another when it goes back
  (`trunk_clear`), from two new pools. Both are small, like lint's and build's,
  and magenta. The conflict scene moves in a way no success or failure scene
  does: two strands that tangle into a knot, where a failure shakes and a pass
  rises. The clear scene unties the knot. Neither touches the header's resting
  outcome, the lamp or the streak.

### The hooks

The post-commit hook is unchanged. The pre-push hook is unchanged too, and it
does not stop a push that conflicts: pushing a conflicting feature branch is a
normal step (sharing work, opening a pull request), and a push to the trunk
itself that has fallen behind is already refused by the remote as not a fast
forward. What the pre-push hook prints comes from `fun-ci wait`, so the trunk
line below shows up at push time without any change to the hook.

### `fun-ci check`

`check` names the trunk it will use and where that came from, and whether
fun-ci fetches it:

```
Trunk: origin/main (origin's default branch), fetched by fun-ci at most once a minute
```

With no trunk found it says so and names the setting (`trunk:` in
`.fun-ci/config`). That is a warning, not an error: a project with no remote
and no trunk branch still runs its pipeline.

## What an agent sees

### `status` and `wait`

After the stage lines comes one trunk line, then the conflicting files, then
the next step:

```
fun-ci: 3f9c2ab "Add shipping to the cart total" on feat/cart
  lint   passed         0.6s
  build  passed         0.3s
  fast   passed         0.3s
  slow   running
  trunk  CONFLICTS      origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind
    lib/cart.rb
    lib/total.rb
Rebase onto origin/main and resolve the conflicts: git fetch origin && git rebase origin/main
fun-ci why 3f9c2ab trunk
```

The other states print one line: `trunk  clean  origin/main 9e1d004, fetched
2m ago, 3 ahead, 4 behind`, `trunk  up to date  origin/main 9e1d004`, `trunk  in
trunk`, `trunk  checking`, or `trunk  unknown  <reason>`. A stale trunk shows
its age plainly (`fetched 3h ago (fetch failed: could not resolve host)`), so
"clean" is never read as more than it is.

The exit codes don't change. Exit codes are a published contract, and a
conflict is not a verdict on the commit. An agent that wants to branch on
integration asks for it with `--trunk`:

- `fun-ci wait --trunk` also waits for the trunk check (it has a budget of its
  own, below), and `status --trunk` and `wait --trunk` exit **6** when the
  verdict would be 0 but the commit conflicts with the trunk.
- A failure still wins: a failed stage exits 1 whatever the trunk says, so an
  agent fixes its own code before integrating.
- `--trunk` with a trunk state of `unknown` exits with the verdict alone. An
  agent can't act on "couldn't check", and the text says why.

The pre-push hook doesn't pass `--trunk`, for the reasons under The hooks.

### `status --json`

The document gains a `trunk` object. The schema stays 1, because adding a field
breaks no reader and no published field changes name:

```json
"trunk": {"state": "conflicts", "ref": "origin/main", "sha": "9e1d004...",
          "as_of": "2026-09-29T10:14:03Z", "fetch": "ok",
          "ahead": 3, "behind": 4, "files": ["lib/cart.rb", "lib/total.rb"],
          "reason": null}
```

`fetch` is `ok`, `failed` or `off`. `files` is empty unless the state is
`conflicts`. `reason` is set only for `unknown`. `runs --json` carries the same
object in each run's document.

### `runs`

A run whose check conflicted gets `CONFLICTS origin/main` at the end of its
line, after the subject, since `runs` lists history and the state is as of
that run's check.

### `why REV trunk`

`trunk` is accepted wherever `why` takes a stage name. It prints what fun-ci
kept of the check: the trunk ref and SHA and when it was fetched, ahead and
behind, git's own merge messages (`CONFLICT (content): Merge conflict in
lib/cart.rb`, and renames and deletions that clashed), and each conflicting
file's conflicted regions with three lines around each, exactly as a merge
would leave them in the file:

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

This is the evidence an agent needs to resolve the conflict without first
running the rebase to see it. `why REV trunk --json` gives the same as one
document, in the shape of a stage's evidence (`excerpts`, `facts`, `problems`),
masked by `Evidence::Masking` and capped by `Evidence::Caps` like any other.

### `events`

A new event, `trunk_checked` (`schema` 1, `event`, `commit`, `branch`, `state`,
`ref`, `trunk_sha`, `files`), each time a run's trunk result is recorded or
changes on a recheck. `--only failures` includes it when the state is
`conflicts`.

## Which ref is the trunk

In order, the first that exists:

1. `trunk:` in `.fun-ci/config`, any name `git rev-parse` accepts
   (`origin/develop`, `upstream/main`, `main`). `Setup::Settings` reads it, and
   a name that doesn't resolve is reported by `check`.
2. The remote's default branch: `refs/remotes/<remote>/HEAD`, which `git clone`
   sets. `<remote>` is `origin`, or the only remote there is.
3. The first of `<remote>/main`, `master`, `develop`, `development`, `trunk`.
4. With no remote, the first local branch of those names.

Otherwise the state is `unknown` ("no trunk; set `trunk:` in .fun-ci/config").
`init` writes nothing for it, in the same spirit as the presets: a list written
at init goes stale when the team renames its trunk.

Commits made on the trunk branch itself are checked the same way. For a
developer committing to `main` and pushing, "conflicts with origin/main" means
exactly "`git pull --rebase` will stop on these files", which is the question
they have.

## How the check works

One `git merge-tree --write-tree` of the commit and the trunk SHA, after two
cheap ancestry checks:

1. `git merge-base --is-ancestor <commit> <trunk>`: yes means `in_trunk`.
2. `git merge-base --is-ancestor <trunk> <commit>`: yes means `up_to_date`.
3. `git rev-list --left-right --count <commit>...<trunk>` for ahead and behind.
4. `git merge-tree --write-tree --name-only --messages <commit> <trunk>`: exit 0
   is `clean`; exit 1 is `conflicts`, with the conflicted paths listed after
   the tree's SHA and the messages after a blank line; anything else is
   `unknown` with git's first line of stderr as the reason (exit 128 for
   unrelated histories, for instance).
5. For `conflicts`, `git cat-file -p <tree>:<path>` for each conflicted file,
   from which the conflicted regions are cut for `why`.

It needs no worktree and no slot. `merge-tree` merges in memory against the
object database the worktrees share, so the check runs beside lint and build
without touching the checkout they run in and without waiting for a free slot.

`merge-tree --write-tree` writes the merged tree and the conflicted blobs into
the repository's object store (measured below: two new objects for one small
conflict). Those are unreachable and `git gc` would remove them in time, but a
check on every commit shouldn't leave anything behind. So fun-ci runs steps 4
and 5 with `GIT_OBJECT_DIRECTORY` pointed at a scratch directory in the state
directory and `GIT_ALTERNATE_OBJECT_DIRECTORIES` at the repository's own
objects, and deletes the scratch directory afterwards. Nothing is written to
the repository.

A git without `merge-tree --write-tree` gives `unknown` ("needs a git whose
merge-tree has --write-tree"). fun-ci finds out by running it and reading the
usage error, not by parsing git's version.

The check has a budget: 5 seconds for steps 1 to 5. A large repository with
rename detection can take a while, and a check that runs over is killed with
its process group and recorded as `unknown` ("over its 5 s budget").

## Keeping the trunk fresh

A merge check against a trunk last fetched yesterday says little, and most
developers don't fetch often. So fun-ci fetches the trunk itself, when the
trunk is a remote's branch:

```
GIT_TERMINAL_PROMPT=0 git fetch --quiet --no-tags --no-write-fetch-head \
  --no-recurse-submodules --refmap= <remote> +refs/heads/<branch>:refs/fun-ci/trunk/<remote>/<branch>
```

- It fetches into a ref of fun-ci's own, `refs/fun-ci/trunk/...`, never into
  `refs/remotes/`. Updating the developer's remote-tracking ref would change
  what `git status` says under them, and would race their own `git fetch` or
  `git pull` for the ref's lock, which can make theirs fail.
- `--refmap=` (empty) is required. Without it git updates
  `refs/remotes/origin/main` as well, as a side effect of any fetch that names
  a refspec (measured below). With it, only fun-ci's ref moves.
- `GIT_TERMINAL_PROMPT=0` stops git from asking for a password. An SSH key
  with a passphrase and no agent can still wait on a prompt, so the fetch has a
  deadline of 20 seconds, after which its process group is killed.
- It happens at most once a minute per project (a row in a new
  `trunk_fetches` table records when and how the last one went), so a burst
  of commits makes one fetch.
- It runs in the trigger, in a thread beside lint and build. In the
  post-commit hook the trigger is already in the background, so the fetch
  holds nothing up. A foreground `fun-ci trigger` waits for it, within its
  deadline, before returning.
- The check then uses whichever of fun-ci's ref and the developer's
  remote-tracking ref is newer: if one contains the other, that one; if they
  have diverged (a force push upstream), fun-ci's ref when its fetch just
  succeeded, otherwise the remote-tracking ref.
- A failed fetch never fails anything. The check goes ahead against the newest
  trunk it has, and the output says how old that is and why the fetch failed.

`trunk_fetch: false` in `.fun-ci/config` turns fetching off, for a machine that
must not touch the network during a commit. Then the "as of" is the time the
remote-tracking ref last moved, from its reflog, or `unknown` when there is no
reflog.

Fetching is on by default. That is a judgment call: fun-ci is local-first, and
this is the first thing it does over the network. The case for it is that
without a fresh trunk the check reports stale news with a straight face, and
the fetch touches nothing of the developer's.

## When it runs, and when it runs again

The result is a fact about a pair of commits: this commit against that trunk
SHA. It never goes stale for that pair; it goes stale when the trunk moves. So
fun-ci checks again whenever it learns the trunk has moved, and only then:

- **Each trigger** fetches the trunk and checks its own commit. If the trunk
  SHA changed, it also checks again the newest run of every other branch of the
  project whose recorded trunk SHA differs. One commit on any branch refreshes
  every branch's line on the board. Each check is one `merge-tree`, about
  10 ms on this repository.
- **`status`, `wait` and `runs`** compare the recorded trunk SHA with the
  current one (fun-ci's ref and the remote-tracking ref, read locally, no
  fetch) and check again when it has moved, recording the result. `wait`
  already writes to the run (`waited_at`) and all three already run git, so
  this adds no new kind of access.
- **The console** only reads. It runs no git; Ruby decides what is true from
  the database, as it does for everything else.

Two processes checking the same pair at once compute the same answer, so whichever
write lands last records the right result. Each write names the trunk SHA it
checked, and a write for an older trunk SHA than the one recorded is dropped,
so a slow check never overwrites a fresher one.

The trunk can move while nobody commits, and then the board shows the last
check until the next commit or agent command. For someone committing every few
minutes that gap is small. If it turns out not to be, the fix is a timer in
the console loop that runs a trigger's fetch and recheck without a commit,
which would be the console's first git call.

## Storage

On `pipeline_runs`, through `Database::ADDED_COLUMNS` like every column added
since the first release: `trunk_ref`, `trunk_sha`, `trunk_state`,
`trunk_ahead`, `trunk_behind`, `trunk_reason`, `trunk_checked_at` and
`trunk_evidence` (the JSON document `why REV trunk` prints, kept only for
`conflicts`, and pruned with the stages' evidence by `Persistence::Retention`).

A new table, `trunk_fetches (project_path TEXT PRIMARY KEY, ref TEXT, sha TEXT,
fetched_at TEXT, error TEXT)`, for the once-a-minute limit and the "as of".

## The renderer protocol

- A run in `board` may carry `"trunk": "conflicts"`. Ruby sends it only on the
  runs that should show the word (the newest run of its branch in its project,
  checked and conflicting), so the renderer decides nothing about which rows
  qualify. The protocol ignores unknown fields, so this needs no new protocol
  version.
- Two event names, `trunk_conflict` and `trunk_clear`, with `run_id`. Ruby
  sends one when the newest run of a branch starts or stops conflicting, after
  stage and milestone events of the same poll. A `TrunkChangeDetector` decides
  them the way `StageChangeDetector` decides stage events.
- A new contract fixture holds a conversation with both events, and a new
  scenario in `contract/scenarios/` pins the row and the two scenes as
  reviewed snapshots.

## Where the code goes

A new `lib/fun_ci/trunk/`, each piece small enough for the code limits:

- `Resolver`: which ref is the trunk, from the settings and the repository.
- `Fetch`: the fetch into fun-ci's ref, its deadline and its once-a-minute
  limit.
- `MergeCheck`: steps 1 to 5 in a scratch object directory, returning a
  `Result` (state, ref, SHA, as-of, ahead, behind, files, reason) and the
  conflicted files' contents.
- `Regions`: the conflicted regions of a file, with their context, as
  excerpts.
- `Recheck`: which runs to check again once the trunk has moved.
- `TrunkText`, `TrunkJson`: the trunk line and object for `status`, `wait`,
  `runs` and `why`.

`Pipeline::Seams` gains `trunk`: what runs the fetch and the check, `nil` for
the real thing. Unit and acceptance tests pass a fake that returns a scripted
`Result`, so they run no git. The real git work is tested in
`test/integration/process/` against temporary repositories with a bare
repository as the remote, per the spawn rules in `CLAUDE.md`.

## Decisions

**Decision: a conflict is a fact about the run, not a stage.** A fifth stage
(`.fun-ci/integrate.sh`) would reuse the stage rows, but a stage has a script,
a pass or fail that settles the run's status, and a place in the verdict. A
conflict would then fail the run, break the streak and set off the explosion
for something the commit's author may not have caused yet.
*Revisit if* teams ask to hold their commits to "integrates cleanly" as
strictly as to "passes the fast suite". Then `--trunk` becomes a level of
`--need`.

**Decision: merge-tree in memory, not a merge in a worktree.** A
`git merge --no-commit` in a slot would need the slot for its duration, and
reset it afterwards, while lint and build want it. `merge-tree` needs neither
and took about 10 ms here.

**Decision: a three-way merge, not a rebase.** A rebase replays the branch
commit by commit and can stop on a conflict in an intermediate commit even when
the merge of the tips is clean; the reverse can happen too. Checking the tips
answers "does the result conflict?" with one call. Replaying each commit
(`git replay`, still marked experimental in git's documentation [unverified])
costs a merge per commit.
*Revisit if* developers hit rebase conflicts the check called clean.

**Decision: fetch into fun-ci's own ref, with an empty refmap.** Both measured
below. *Revisit if* a hosting setup refuses fetches of an explicit refspec.

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

Built in the order of their numbers. Each process-level one runs in a
temporary repository whose remote is a bare repository in the same temp root.

### 11.1 A run records how its commit stands against the trunk
**Given** a project whose remote's `main` has moved on since the branch was cut
**When** a run is triggered for the branch's commit
**Then** the run records `trunk_ref` `origin/main`, the trunk SHA, ahead and
behind, and the state `clean` or `conflicts` as a merge of the two would be
**And** a commit that contains the trunk's tip records `up_to_date`, and one
the trunk contains records `in_trunk`.
*Bites:* today nothing looks at the trunk.

### 11.2 The trunk is found, or configured
**Given** repositories with `origin/HEAD` set, with only `origin/master`, with
no remote and a local `develop`, with `trunk: upstream/main` in
`.fun-ci/config`, and with none of these
**When** a run's check starts
**Then** the trunk is `origin/<HEAD's branch>`, `origin/master`, `develop`,
`upstream/main`, and for the last `unknown` with the reason naming `trunk:`.

### 11.3 A conflict is not a failure
**Given** a run whose stages pass and whose commit conflicts with the trunk
**When** the run finishes
**Then** its status is `completed`, it counts towards the streak, and
`status` and `wait` exit 0.

### 11.4 `status` and `wait` print the trunk line and the next step
**Given** runs in each state
**When** `fun-ci status` runs
**Then** it prints the trunk line of that state after the stages; for
`conflicts`, the files and the rebase command, then `fun-ci why <sha7> trunk`.

### 11.5 `--trunk` makes a conflict an exit code
**Given** a run that passed and conflicts
**When** `fun-ci status --trunk` runs, and `fun-ci wait --trunk`
**Then** both exit 6
**And** a run that failed and conflicts exits 1, and one whose check is
`unknown` exits with its verdict alone
**And** `wait --trunk` doesn't return before the check has finished or run out
of its budget.

### 11.6 `status --json` and `runs --json` carry the trunk object
**Given** the runs of 11.4
**When** they run with `--json`
**Then** each document has `trunk` with `state`, `ref`, `sha`, `as_of`,
`fetch`, `ahead`, `behind`, `files` and `reason`, and `schema` is still 1.

### 11.7 `why REV trunk` shows the conflicted regions
**Given** a conflicting run
**When** `fun-ci why REV trunk` runs
**Then** it prints the trunk and when it was fetched, git's merge messages, and
each conflicted file's conflicted regions with three lines around each
**And** `--json` gives the same as one document, masked and capped like a
stage's evidence.

### 11.8 The check leaves nothing in the repository
**Given** a conflicting commit and trunk
**When** the check runs
**Then** `git count-objects` reports the same before and after, and no ref
outside `refs/fun-ci/` has moved.

### 11.9 fun-ci fetches the trunk without touching the developer's refs
**Given** a remote whose `main` has a commit the clone hasn't fetched
**When** a run is triggered
**Then** `refs/fun-ci/trunk/origin/main` is the remote's `main`, the check uses
it, and `refs/remotes/origin/main` and `FETCH_HEAD` are unchanged
**And** a second run within a minute doesn't fetch again
**And** with `trunk_fetch: false` nothing is fetched.
*Bites:* without `--refmap=`, `refs/remotes/origin/main` moves too.

### 11.10 A fetch that fails or hangs never holds up or fails a run
**Given** a remote that can't be reached, and one that never answers
**When** a run is triggered
**Then** the stages run and are recorded as they would be, the check uses the
newest trunk it has, `fetch` is `failed` with the reason, and the hanging fetch
is killed at its 20 s deadline.

### 11.11 A moved trunk is checked again
**Given** branches whose newest runs were checked against an older trunk SHA
**When** a run on any branch fetches a newer trunk, or `status` finds the
trunk ref has moved
**Then** those runs are checked again against the new SHA and recorded
**And** a check for an older trunk SHA than the one recorded doesn't replace
it.

### 11.12 The board shows the conflict on the branch's newest run
**Given** a branch whose newest run conflicts, and an older run of it that
conflicted too
**When** the console draws the board
**Then** Ruby's `board` carries `"trunk":"conflicts"` on the newest run only,
and the renderer draws `conflict` in bold magenta after its branch
**And** no other state draws anything.

### 11.13 The header marks a branch starting and stopping to conflict
**Given** a branch's newest run that starts conflicting, and later a newer run
of it that doesn't
**When** the console polls
**Then** Ruby sends `trunk_conflict`, then later `trunk_clear`, for those runs,
and the header plays a scene from each one's pool, queued like the milestones'
scenes, without changing its resting outcome, the lamp or the streak.

### 11.14 `events` reports trunk checks
**Given** runs being checked and checked again
**When** `fun-ci events` runs
**Then** it prints a `trunk_checked` line for each result recorded or changed,
and `--only failures` keeps those whose state is `conflicts`.

### 11.15 `check` names the trunk
**Given** the repositories of 11.2
**When** `fun-ci check` runs
**Then** it names the trunk and where it came from, whether fun-ci fetches it,
and for the last repository warns and names `trunk:`, exiting as it would
without the warning.

## Measurements

What this design rests on, measured with git 2.53.0 on macOS in a scratch
repository, and on this repository for the timing:

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
  `FETCH_HEAD`.
- A `reference-transaction` hook ran for one `git update-ref` and one
  `git checkout` and logged 20 lines: a `prepared` and a `committed` call for
  each transaction, the checkout's including `HEAD`.
- `git clone` set `refs/remotes/origin/HEAD` to the branch checked out in the
  source repository at the time, which need not be the trunk. Resolution step 2
  trusts it anyway because on hosted remotes it is the default branch the team
  chose; `trunk:` overrides it where that is wrong.

Not measured: the git release that added `merge-tree --write-tree` (2.38 by
its release notes [unverified]), which is why the check detects support by
running it; and how long `merge-tree` takes on a repository with hundreds of
thousands of files, which is what the 5 s budget guards against.

## For the owner to settle

These are judgment calls this design makes; each is easy to reverse before
building:

1. Fetching the trunk over the network by default, in a tool that has been
   local-only so far.
2. Not stopping a push that conflicts.
3. `--trunk` and exit code 6 as the way an agent opts in, rather than a new
   `--need` level.
4. The word `conflict` in magenta on the board, and two new header pools.
