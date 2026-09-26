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
in SQLite and keeps no build artefacts or logs.

## The pipeline

A project describes its pipeline with four executable scripts in `.fun-ci/`:
`lint.sh`, `build.sh`, `fast.sh` and `slow.sh`. Each gets the commit hash as its
first argument, and its exit code decides pass (0) or fail.

Lint and build run in parallel. If both pass, the slow suite forks into the
background and the fast suite runs in the foreground. The `pre-push` hook waits
for the fast suite and blocks the push if lint, build or fast failed; the
`post-commit` hook runs the whole pipeline in the background so a commit is
never held up.

Each run happens in a git worktree of its own, checked out at the commit it
tests, so the developer keeps editing while it runs. A newer commit on the same
branch cancels the older run if it hasn't finished: the latest commit wins.

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
you know, you go. An animated picture fills the top 14 rows; below it, one row
per run, newest first:

```
> 8d552d0  main  Lint 0.3s  Build 1.2s  Fast ⠁ 9s  Slow --  RUNNING  just now
  c67191d  main  Lint 0.3s  Build 1.2s  Fast 1.8s  Slow 47s  PASSED  10m ago

  j/k move   c cancel   q quit
```

- A row reads like a sentence: commit, branch, the four stages with their
  times, the outcome, and when. There are no column headings.
- The colour is on the stage times themselves, so the board can be scanned for
  colour without reading. A wall of green means everything is fine.
- A passed stage is green. A failed one is bold red with the word in it
  (`Fast FAIL 6.2s`). A timed-out one is bold yellow (`Fast TIMEOUT 10s`). The
  running stage is cyan, with a spinner and a time that ticks up, so the eye
  goes straight to where the action is. A stage not reached yet is a dim `--`.
- The outcome word matches: PASSED in bold green, FAILED in bold red, TIMED OUT
  in bold yellow, RUNNING in bold cyan. A scheduled run is a dim
  `Scheduled...`; a cancelled one is dim and colourless, neither good nor bad.
- The relative time is dim: always there, never competing.
- `j` and `k` (or the arrows) move the cursor, `c` cancels the run under it,
  `q` quits. Cancelling a scheduled run happens at once; a running one asks
  first, naming it (`Cancel feat/search (d4e5f67)? y / n`), because a process
  gets killed.
- The board is always live, so there is no refresh key. With no runs yet it
  says `No runs yet.`
- It works from 60 columns wide up.
- The streak counts consecutive passed runs; a running run neither breaks nor
  extends it. It sits at the top right of the header, `7 in a row!` in green,
  or `streak broken` in plain white after a failure, since the header shouldn't
  alarm; the rows do that.

## Animations

Animations do both of fun-ci's jobs: they report what happened at a glance, and
they are the fun. Everything an animation reports is also in the rows' text.

**The header** is a picture painted in light: a night sky over the hills when
nothing is happening, and a rocket while a run is running. When a run reaches a
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
  outcome of the latest finished run, calm for a pass and with a warning in view
  for a failure, until the next run starts (AT-7.5).

The pools today:

| Milestone | Scenes |
|---|---|
| lint passed | a teal comet sweeping a line clean (`sweep`), teal rings spreading from a tick (`ripple`) |
| build passed | amber blocks stacking into a pyramid (`bricks`), two amber gears turning (`gears`) |
| fast passed | a lightning strike and a neon tick (`flash`), a very happy YAY (`yay`) |
| passed | fireworks (`success`), a trophy (`celebrate`), dancing leprechauns (`leprechauns`) |
| failed | the explosion, which shakes (`explosion`) |

Lint's scenes are teal and move across, build's are amber and stack or turn,
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
| The database is busy | fun-ci waits for it, for up to 5 seconds; if it stays busy, the stages run on unrecorded and fun-ci says once to trigger again | the pipeline's own |
| The database can't be written (a full disk, a read-only file) | The stages run on unrecorded, and fun-ci says once where the database is and to check the disk | the pipeline's own |

The slow suite runs in the background, so its failures and timeouts show only
on the console. If its process dies without finishing, the console notices on
its next poll and shows the slow stage, and the run, failed.
