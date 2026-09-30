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
   passes builds a streak. It stays calm to look at even when something
   breaks: a failure is feedback, not an alarm.

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
- The console says so on the line under a branch that conflicts,
  `conflicts with main`, in lilac, a hue no state uses, and the row needs you
  as much as a timeout. It follows the branch's latest settled check, so it
  doesn't flicker off while a new commit is being checked. A stale trunk is
  said beside its project's name, `trunk last fetched 2h ago`.
- `status` and `wait` print a trunk line with its age, and for a conflict the
  files, when and how to integrate (a pull on the trunk branch, a merge
  elsewhere, never a force push), and `fun-ci why <sha> trunk`, which shows the
  conflicted regions. `--trunk` makes a conflict exit 6 and waits for the check.

## A run's states

A stage is `scheduled`, `running`, then `completed`, `failed`, `timed_out` or
`cancelled`. A run is `scheduled`, `running`, then `completed`, `failed` or
`cancelled`. The console says scheduled, running, passed, failed, timed out
and cancelled.

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

`fun-ci console` is one screen: you look, you know, you go, and it stays calm
to look at even when something broke, since a failure is feedback, not an
alarm. An animated picture fills the top 14 rows; below it the header's night
sky carries on, dusky violet under the horizon and deepening to night, and
each project's branches sit under the project's name, one row per branch:

```
  S T R I N G S - K A T A   ─────────────────────────────────────────────
▗▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▖
▌   a-life-of-its-own                 ✓─✓─◆─✓    failed in fast · 1.4s       6m
▌     conflicts with main
▝▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▘
    main                              ◌┄◌┄◌┄◌    scheduled                  now


  A G E N T - T O M E      trunk last fetched 2h ago   ────────────────

▌   fix/crash                         ✓─◆┄·┄·    failed in build · 0.9s     40m

▌   refactor/extract-the-evidence…    ✓─✓─◇─✓    timed out in fast · 10s    25m


  F U N - C I   ─────────────────────────────────────────────────────────

▌   feat/search                       ✓─✓─⠹─⠹    running fast and slow · 7s now

    trunk-conflicts                   ✓─✓─✓─✓    passed                     14m


   j/k  move     c  cancel     q  quit
```

- A branch has one row, its newest run's, so the table says where each branch
  stands. The row reads as one phrase: the branch, four marks for lint,
  build, fast and slow, what happened in fun-ci's own words, and when.
  The words are exact: `failed in fast · 1.4s`, `timed out in fast · 10s`,
  `running fast and slow · 7s`, `passed`, `scheduled`, `cancelled`, and
  `3 runs cancelled` for a branch's runs cancelled one after another, as a
  rebase leaves them. The calm comes from how the table looks, never from
  softer words.
- Each mark says its stage's state by shape as well as colour: `✓` passed,
  `◆` failed, `◇` timed out, a spinner while it runs, `·` not reached (a
  stage a failure stopped too), `◌` waiting to run, `–` cancelled with its
  run. Without column headings the marks come in lint, build, fast, slow
  order, and the words name the stage. A link leads into each mark, a line
  in half its colour once the stage was reached and a faint dotted one
  before, so a run fills its track from left to right.
- A row that needs you or is running has a stripe down its left edge in the
  colour of why: coral for a failure, amber for a timeout, lilac for a
  conflict, blue while it runs. Counting the stripes is the glance.
- A project's rows sit under its name in letter-spaced capitals, followed by
  a rule that fades out where the rows end. The project
  that most needs you comes first, and within a project a failure, then a
  timeout or a conflict with the trunk, then running, scheduled, passed and
  cancelled rows, newest first among equals. With one project there is no
  label.
- One deep block, a card with rounded corners, holds the row the cursor is
  on, or, with no cursor, the first row that needs you: a failure, a timeout,
  a conflict. It is wine when its row needs you and indigo when the cursor
  only rests on a calm row, so the card never looks like trouble without
  cause. When nothing needs you and there is no cursor there is no block.
  The block breathes, lightening and easing once every four seconds.
- Along a running row a soft band of light travels, over and over, so a run
  in progress reads from the corner of the eye; it leaves the marks alone,
  where the spinner already moves.
- Passed rows are pale, at about a third of their brightness. When nothing
  needs you, a project's passed branches fold into one pale line, each with
  its age (`main 1h   kata/strings 5h   passed`); the rows come back when
  something needs you. Each folded branch has a pale `✓`. A board where everything has passed gets one firefly,
  no brighter than a pale name, wandering in the open space below the table.
- The colours come from the header's night scenes: teal for passed, coral for
  failed, amber for timed out, blue for running, lilac for a conflict,
  violet-greys for names and labels. No two states share a hue.
- The marks, the words and the age follow the longest branch name, so each row
  reads as one phrase and the block is only as wide as what it holds. A wider
  terminal widens the table by up to 24 columns, a third of them to the
  names, a third between the marks and the words and a third before the age;
  past that the table sits in the middle, so a row never stretches beyond a
  measure the eye takes in at once. Nothing wraps, and nothing that says what
  happened is cut: as the terminal narrows, the gaps close, then the margins,
  and only then is a branch name cut with `…`. It works from 60 columns wide
  up.
- On a short screen the table gives up, in this order: the passed rows fold
  into one line per project; the folded lines go, counted beside the keys
  (`2 passed not shown`); the blank lines between rows close up; the labels
  go, each row then naming its project first (`strings-kata  a-life…`), and a
  stale trunk takes a line of its own above the keys. The cursor's row always
  stays on screen, the rows it pushed off counted (`… 4 more below`).
- `j` and `k` (or the arrows) move the cursor, which takes the block; `c`
  cancels the run under it, and is offered only while a run is running or
  waits to start; `q` quits. The footer shows each key on a cap with what it
  does beside it. Cancelling a scheduled run happens at once; a running one
  asks first, naming it (`Cancel feat/search (d4e5f67)?` with `y yes` and
  `n no`), because a process gets killed.
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

**Stage effects** play on a single stage's mark and show *which* stage it
was: a failed stage flares white on red and cools into its row, a timed-out
one pulses amber twice, and a passed one lights gold and fades back. When the
last stage passes, its mark lights on its turn, a fifth of a second a stage.

**Row washes** play across the whole row of a run that has just ended: it
flushes in the colour of how it ended, teal for a pass, coral for a failure,
amber for a timeout, and the colour drains away from left to right over a
second and a half. The wash leaves the marks to their stage effects, so a
pass still lights them gold one after another.

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
