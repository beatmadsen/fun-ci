# fun-ci design

What fun-ci is for and what the developer sees: its two goals, the principles
that follow from them, the pipeline, the states a run goes through, the console
and its animations, and what happens when something goes wrong. This file
describes intent. The technical decisions are in
[`architecture.md`](architecture.md), the requirements not yet built are in
[`acceptance-tests.md`](acceptance-tests.md), and the messages between the gem
and the renderer are in [`renderer-protocol.md`](renderer-protocol.md).

## Goals

fun-ci exists for two reasons, and everything else in this file serves one of
them.

1. **All is well, or it isn't, at a glance.** It must be extremely easy for the
   developer to know whether their code is fine. The console sits on a second
   screen and is read from the corner of the eye, not studied: "lint worked,
   build worked, there goes the fast suite, that worked too", or "not
   everything passed, I'll look closer". Motion and colour carry that. The text
   is there for when they choose to look.
2. **It is fun.** fun-ci is a CI you want to watch. A pass is celebrated, a
   failure gets a proper explosion, the scenes take their time, and a run of
   passes builds a streak.

The two meet in the animations. An animation that reports a state (a stage
failed, the run passed) must read at a glance; one that is only there for fun
must never hide a status.

## Principles

**Fast feedback, enforced.** "Continuous" means the pipeline and its feedback
are fast, so every stage has a budget, and a stage that overruns it is killed
and reported as timed out:

| Stage | Budget | Runs | Blocks |
|---|---|---|---|
| Lint | 30 s | in parallel with build | the push |
| Build | 30 s | in parallel with lint | the push |
| Fast suite | 10 s | after lint and build pass | the push |
| Slow suite | 5 min | in the background, beside the fast suite | nothing |

A timeout is a design signal ("your fast suite has grown too heavy"), not a bug
in the code, so it looks different from a failure: yellow, not red.

**Simple.** One screen, three keys, no drill-down. A new user understands a row
the first time they see one.

**Reliable.** fun-ci is a safety net, so it has to work, and it must never
strand the developer: when fun-ci or its setup is missing, the commit or push
goes ahead without CI and says so.

**Local.** Everything runs on the developer's machine. fun-ci records outcomes
in SQLite and keeps no build artefacts. Of what a stage prints it keeps only
the end of a failed stage's output, so whoever reads the failure can see why.

## The pipeline

A project describes its pipeline with four executable scripts in `.fun-ci/`:
`lint.sh`, `build.sh`, `fast.sh` and `slow.sh`. Each gets the commit hash as its
first argument, and its exit code decides pass (0) or fail.

Lint and build run in parallel. If both pass, the slow suite forks into the
background and the fast suite runs beside it in the foreground, in the same
worktree; [Stages side by side](#stages-side-by-side) says what that lets each
stage read and write. The `post-commit` hook
runs the whole pipeline in the background so a commit is never held up. The
`pre-push` hook waits for the fast verdict of each commit the push sends and
stops the push if lint, build or fast failed; a commit whose run has already
finished goes through at once.

Each run happens in a git worktree of its own, checked out at the commit it
tests, so the developer keeps editing while it runs. A newer commit on the same
branch cancels the older run if it hasn't finished, unless an agent is waiting
on it: the latest commit wins. A run is never cancelled by another run of its
own commit.

## Stages side by side

Two pairs of stages run at the same time, in the same worktree. Lint and build
start together from the commit's checkout; once both pass, the fast and slow
suites start together from what the build left.

| Stage | Runs beside | Starts from | Reads | Writes |
|---|---|---|---|---|
| `lint.sh` | `build.sh` | the checkout | the source alone | nothing the build uses |
| `build.sh` | `lint.sh` | the checkout | the source | the build's output, test code included |
| `fast.sh` | `slow.sh` | what `build.sh` built | the source and the build's output | only what it alone uses |
| `slow.sh` | `fast.sh` | what `build.sh` built | the source and the build's output | only what it alone uses |

Two stages that run side by side and write the same files break each other: a
Gradle test run and a Gradle integration test run, compiling the tests into
one `build/` directory at once, delete the files the other is reading. So
lint works on the source code only, and a linter that needs compiled code
(spotbugs, or a checkstyle task that compiles first) goes in `build.sh`, after
compiling, or in `fast.sh`. `build.sh` compiles everything the suites run, so
neither suite compiles anything. Each suite may write its own reports, and
what its tool shares safely between runs: state under the tool's own lock, or
a record no verdict reads, such as a test runner's cache.

The scripts `fun-ci init` writes keep to this, and each says in its first
comment what it runs beside. `script/check_init_templates.rb` runs each
stack's in its pinned image: it lists what each stage of a pair writes, run
alone from where it starts, fails on a file both write, and runs the suites
side by side to see that both still run their tests.

## Agents

A coding agent is a user too, and it can't glance at a second screen. It asks
fun-ci about commits instead, and branches on exit codes. The commit is the
only event: fun-ci tests commits, speaks up after one, and never looks at
uncommitted files.

- A commit's output ends with the command that gets its verdict:
  `fun-ci: testing 3f9c2ab. Verdict: fun-ci wait 3f9c2ab --need all`.
  `fun-ci init` tells agents, in `AGENTS.md` or `CLAUDE.md`, to run it in the
  background after each commit.
- `fun-ci wait` returns once the level the agent needs is decided: `build`
  (lint and build), `fast` (the default) or `all` (the slow suite too). The
  first failure ends the wait. `--within 30s` gives up at the agent's deadline.
- `fun-ci status` says where a run stands without waiting, `fun-ci runs` lists
  the recent runs, and `fun-ci events` prints what happens as JSON lines.
- The verdict is the exit code, one per outcome (the README lists them), and
  `--json` gives the same facts to a program. Both are a contract: a JSON
  document carries a schema version, and a field, once published, keeps its
  name.
- A failed stage comes with its evidence, so an agent never reruns a suite to
  find out why. `status` and `wait` show a digest: for a stage that ran over
  budget, what it was running when it was stopped; then the failures its test
  reports name, or else the first excerpt, or else its last lines. The digest
  ends with the command that shows the rest, `fun-ci why 3f9c2ab fast`.
- `fun-ci why` prints everything kept: how the stage exited against its
  budget, the stages that shared its worktree, each failure with its whole
  message and its own output, each excerpt under its title and where it came
  from, and anything that went wrong collecting them. `why --raw` prints the
  output itself (its first megabyte and last seven), and `--json` the same as
  one document. When all fun-ci kept is the output's last lines, `why` says so
  and names the setting that keeps more, so an agent can write the extractor
  itself.
- A project says what else to keep under `evidence:` in `.fun-ci/config`: a
  `grep` for lines, a `section` between two patterns, what a stage wrote to a
  `log-file`, the records of a `json-log` at or above a level, or its own
  command (`run:`) in any language. With no configuration, presets for 34
  tools run when the project's files and the failure show that tool.
  `fun-ci check` lists the presets that apply, and `fun-ci extract` tries a
  stage's extractors on a saved output, so a change can be tried without a
  commit. Secrets are masked before anything is kept.

## The trunk

Integrating often is half of continuous integration, so each run also asks how
its commit stands against the team's trunk (`main`, `master`, `develop`,
whatever `trunk:` in `.fun-ci/config` names, else the remote's default
branch). A conflict found within seconds of the commit that caused it is small
and cheap to resolve.

- A check finds how many commits each side has that the other lacks, and, when
  both have some, whether merging them conflicts, and in which files. It merges
  in memory and leaves nothing in the repository.
- A conflict is not a failure. The code in the commit may be fine; what is late
  is its integration. It changes no stage, no run status, no streak and no exit
  code, unless an agent asks with `--trunk`.
- fun-ci fetches the trunk itself, at most every 5 minutes, into a ref of its
  own, touching none of the developer's; the first fetch says so, and
  `trunk_fetch: false` stops it. A trunk fetched over an hour ago, or whose
  last fetch failed, is stale, and every line that depends on it says so.
- The console marks a branch whose newest run conflicts: `conflicts main` in
  magenta after its name, the one colour nothing else on the board uses, or
  `↯ main` where the words don't fit, which the footer then explains.
  The marker follows the branch's latest settled check, so it doesn't flicker
  off while a new commit is being checked. Nothing else about the trunk is on
  the rows; stale trunks get one dim note in the footer.
- `status` and `wait` print a trunk line with its age, and for a conflict the
  files, when and how to integrate (a pull on the trunk branch, a merge
  elsewhere, never a force push), and `fun-ci why <sha> trunk`, which shows the
  conflicted regions. `--trunk` makes a conflict exit 6 and waits for the check.

## A run's states

A stage is `scheduled`, `running`, then `completed`, `failed`, `timed_out` or
`cancelled`. A run is `scheduled`, `running`, then `completed`, `failed` or
`cancelled`. The console calls them Scheduled, RUNNING, PASSED, FAILED, TIMED
OUT and CANCELLED.

A run's status follows from its stages alone: `failed` once any stage
has failed or timed out, `completed` once all four have passed, and `running`
until then. `failed` and `cancelled` are final. The status is settled in one
database statement each time a stage ends, so the order in which the
foreground pipeline and the background slow suite finish can't change it.

Along the way a run reaches **milestones**, each of which the developer should
see happen: `lint passed` and `build passed` (in either order), `fast passed`,
then `passed` (the slow suite passed too), or `failed` at any point. A run
fails once, however many of its stages fail.

## The console

`fun-ci console` is one screen, like a departure board at a station: you look,
you know, you go. An animated picture fills the top 14 rows; below it, after a
blank line, the stages' names, then one row per run, newest first:

```
                                    lint     build    fast     slow
▌›8d552d0  feat/search      fun-ci  ✓ 0.3s   ✓ 1.2s   ⠹ 9s     ⠹ 9s     RUNNING     now
▌ 93d480c  a-life conflicts main  kata  ✓ 2.3s   ✓ 7.8s   ✗ 1.4s   ✓ 1.3s   FAILED   6m
  c67191d  feat/search      fun-ci  ✓ 0.3s   ✓ 1.2s   ✓ 1.8s   ✓ 47s    passed      10m

  j/k move   c cancel   q quit   kata: trunk 2h old
```

- A row reads like a sentence: commit, branch, project, the four stages with
  their times, the outcome, and when. Each stage has its own column, always
  in the order lint, build, fast, slow, so the eye runs down a column instead
  of reading along a row.
- Each stage shows its state by shape and colour together: a green `✓` for
  passed, a bold red `✗` for failed, a bold amber `▲` for timed out, a cyan
  spinner with a time that ticks up for running, a faint `·` for not reached,
  `–` for cancelled and a grey `◌` for waiting to run. A wall of green ticks
  means everything is fine.
- The newest run of each branch carries its state in a bar at the left edge,
  so reading down that edge gives every branch's health; a running run's bar
  pulses. A run that a newer run of its branch replaced is dimmed, its outcome
  in lower case: a failure already fixed no longer shouts. A current failure
  or timeout, and only trouble, gets a dark band of its colour across the row.
- Runs of a branch cancelled one after another, as a rebase leaves them, fold
  into one row: `detached ×25`, faint, with no stages.
- The outcome word matches: PASSED in bold green, FAILED in bold red, TIMED
  OUT in bold amber, RUNNING in bold cyan. A scheduled run says `waiting` in
  grey, and a cancelled one is faint, neither good nor bad.
- The project shows, in grey, only when the board holds more than one. The
  age is short (`now`, `6m`, `2h`, `3d`) and faint: always there, never
  competing.
- Nothing wraps. As the terminal narrows, the SHA goes first, then the project
  shrinks to its initial, then the stages keep their marks and lose their
  times; a branch too long for its column is cut with `…`. It works from 60
  columns wide up.
- `j` and `k` (or the arrows) move the cursor, a white `›` with the branch in
  bold white and the row's band brightened; `c` cancels the run under it,
  `q` quits. Cancelling a scheduled run happens at once; a running one asks
  first, naming it (`Cancel feat/search (d4e5f67)? y / n`), because a process
  gets killed.
- The board is always live, so there is no refresh key. With no runs yet it
  says `No runs yet.`
- The streak counts consecutive passed runs; a running run neither breaks nor
  extends it. It sits at the top right of the header, `7 in a row!` in green,
  or `streak broken` in plain white after a failure, since the header shouldn't
  alarm; the rows do that.

## Animations

Animations do both of fun-ci's jobs: they report what happened at a glance, and
they are the fun. Everything an animation reports is also in the rows' text.

**The header** is a picture painted in light: a rocket while a run is running,
and a quiet scene when nothing has happened for a while. When a run reaches a
milestone, the header plays a scene for it (AT-7.3):

- Each milestone has its own pool of scenes, and the scene is picked from that
  pool at random. No scene belongs to two success pools, so a viewer learns
  which scene means what.
- The scenes grow bigger along the path: the smallest for lint and build,
  bigger for the fast suite, the biggest for the whole run passing.
- Scenes are told apart by motion, size and colour, never by their lettering
  alone and never by red against green alone. A failure moves differently from
  every success (a shake or a flash against a calm rise), so "look closer"
  reads even when the colour doesn't.
- Scenes queue and each plays to its end (AT-7.4). They may be long; this is
  fun CI, and commits rarely come more than one every few minutes.
- When the queue is empty and nothing is running, the header rests on the
  outcome of the latest finished run: a calm dusk with a tick for a pass, a
  pulsing hazard sign for a failure (AT-7.5).
- Five minutes after that run finished (or at once, if no run has), the header
  goes quiet: it shows a quiet scene picked at random, the starry night, an
  aurora, fireflies, a fire in a medieval stone hearth while a storm rages outside, or a moonlit island with a palm, and every five minutes another of them takes over, until a run starts. A small lamp in the lower left
  corner keeps the latest outcome in view: steady green after a pass, a slow
  red flicker after a failure, none before any run has finished (AT-7.7). The
  quiet state means "nothing has happened for a while"; the lamp answers "was
  the last one fine?".

The pools today:

| Milestone | Scenes |
|---|---|
| lint passed | a teal comet sweeping a line clean (`sweep`), teal rings spreading from a tick (`ripple`), a spirit level settling true (`level`) |
| build passed | amber blocks stacking into a pyramid (`bricks`), two amber gears turning (`gears`), a hammer ringing on an anvil (`anvil`) |
| fast passed | a lightning strike and a neon tick (`flash`), a very happy YAY (`yay`), a jump to warp speed (`warp`) |
| passed | fireworks (`success`), a trophy (`celebrate`), dancing leprechauns (`leprechauns`), a sunrise over the hills (`sunrise`) |
| failed | the explosion (`explosion`) and shattering glass (`shatter`), both of which shake |
| a branch starts conflicting with the trunk | two magenta strands braid into a knot (`tangle`) |
| a branch stops conflicting | the knot loosens and the strands draw apart (`untie`) |
| quiet (nothing for five minutes) | the starry night (`idle`), an aurora (`aurora`), fireflies (`fireflies`), a fire in a medieval stone hearth with a storm at the window (`fireplace`), a castaway's island by moonlight (`island`), snow falling on a pine forest (`snowfall`) |

Lint's scenes are teal and move across or settle, build's are amber and stack, turn or strike,
so the two small ones can be told apart without reading.

**Stage effects** play over a single stage's column and show *which* stage it
was: a failed stage is flanked by blasts, a timed-out one pulses yellow, and a
passed one flashes.

**The footer** joins in for a failure (`>>> FAST FAILED <<<`, fading) and for a
pass (`* * * NICE! * * *`).

## When something goes wrong

Every failure should be understandable at a glance and recoverable without
digging into internals: the cause obvious, the next step clear.

| Situation | What the developer sees | Exit code |
|---|---|---|
| A stage fails | The script's output, `Fast suite failed.` (or `Lint`, `Build`), and what to do next: `Fix the failing tests above, then try again.` | non-zero |
| A stage overruns its budget | `Fast suite killed -- exceeded 10s time budget.` and advice on what to do | non-zero |
| fun-ci isn't installed | The hook says so and how to install it; the commit or push goes ahead | 0 |
| No `.fun-ci/`, or a script missing or not executable | `fun-ci: ...` naming the problem, then `Commit will proceed without CI.` | 0 |
| The commit doesn't exist | `fun-ci: commit <sha> not found in this repository.` | non-zero |
| The commit or branch is missing | `fun-ci: commit hash and branch name are required.` and the usage | non-zero |
| A newer commit on the same branch | `Cancelled stale pipeline for <old>. Starting fresh for <new>.` | carries on |
| A pushed commit's fast verdict is a failure | The run's stages, then `fast failed:` and the failures it reported or its last lines; the push stops | non-zero |
| The trunk can't be fetched | The check goes ahead against the trunk fun-ci has, marked STALE with the fetch's error | the pipeline's own |
| The database is busy | fun-ci waits for it, for up to 5 seconds; if it stays busy, the stages run on unrecorded and fun-ci says once to trigger again | the pipeline's own |
| The database can't be written (a full disk, a read-only file) | The stages run on unrecorded, and fun-ci says once where the database is and to check the disk | the pipeline's own |

The slow suite runs in the background, so its failures and timeouts show on
the console and to an agent that asks (`status`, `wait --need all`, `events`),
never in the commit or the push. If its process dies without finishing, the
console, or a waiting agent, notices on its next poll and records the slow
stage, and the run, failed.
