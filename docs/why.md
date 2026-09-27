# fun-ci why, and the extractors that find the evidence

The design of `fun-ci why` and of what it reads: evidence about a failed stage,
picked out at the moment the stage fails by extractors that fun-ci chooses for
the project's stack, and that a project can add to with its own. This file is
a plan. The requirements are in [`acceptance-tests.md`](acceptance-tests.md),
§10, and once they are built, the decisions below move into
[`architecture.md`](architecture.md), what the developer sees moves into
[`design.md`](design.md), and this file goes.

## The problem

An agent that is told a stage failed should never have to rerun the suite to
find out why: the fast suite alone can take ten seconds, the slow suite five
minutes, and a rerun may not fail the same way. So fun-ci has to keep enough
at the time of failure to answer "why" later.

Today it keeps two things for a failed or over-budget stage (AT-9.5, AT-9.7):
the last 200 lines of what the stage printed, and the failures named in any
JUnit XML or fun-ci JSON the stage wrote into `FUN_CI_REPORT`. That is enough
for a Ruby project whose test runner prints its failures last. It falls short
wherever the cause is somewhere else:

- Gradle and Maven print the failing test's stack trace far above the last
  lines, then a summary and a path to an HTML report.
- A build or type checker can print hundreds of errors, and the first one is
  the cause of the rest.
- A Rails or Spring test writes the interesting part to `log/test.log` or a
  log file of its own, not to the terminal.
- Logs configured with a JSON appender (logstash-logback-encoder, pino,
  structlog, lograge) print one JSON object per line, and the exception is a
  field inside one of them, among thousands of lines at `debug`.
- A JVM that crashes writes `hs_err_pid<N>.log` in the working directory.
- A stage that runs over budget is killed, and its last lines say nothing
  about what it was stuck on.

fun-ci can't know every stack and every logging setup. So the design is a set
of built-in extractors, with presets for the popular stacks that fun-ci picks
by what it finds, and a way for a project to add its own, in whatever language
it already uses.

## Goals

1. `fun-ci why` shows everything fun-ci kept about a failed stage, and an agent
   rarely needs more.
2. Collecting it never changes a stage's verdict, and never holds a verdict up
   by more than a small, fixed budget.
3. A project whose failures don't fit the built-ins can fix that in its own
   repository, with a line of config or a script, and try the change without
   making a commit.
4. With no configuration, fun-ci runs the presets that apply to the project
   and the failure, and only those, so presets for many stacks cost a project
   nothing for the stacks it doesn't use.

Not goals: keeping build artefacts (screenshots, coverage, binaries), which the
Local principle in `design.md` rules out; and interpreting a failure (saying
*what* is wrong with the code), which is the agent's job.

## Where evidence can come from

At the moment a stage fails, and only then, all of these are available:

| Source | What it holds | How long it lasts |
|---|---|---|
| The stage's output | stdout and stderr, as one stream in the order printed | until the stage is recorded |
| `FUN_CI_REPORT` | the test reports the stage wrote | removed when the stage is recorded |
| The worktree slot | log files, crash files, reports the build tool wrote in its own place | until the next run takes the slot |
| The stage's process group | for an overrun, the processes still running, before the kill | until the kill |
| The run itself | stage, state, exit status or signal, duration, budget, commit | kept in the database |

Almost all of it is gone within seconds, so extraction happens where the
stage is run, while it still holds its slot, before its state is recorded.
Today there are two such places: `StageRunner` for lint, build and fast, and
`BackgroundWrapper` in the forked child for the slow suite, each with its own
`keep_evidence`. The first step of this work is one path for a failed stage
that both call, so the slow suite, the stage most likely to need evidence,
gets everything below too.

Three traps come with the worktree slot:

- Slots are reused, and `git clean -fd` keeps ignored files, so a log file or
  a report directory can hold a previous run's content. So when the stage
  starts, fun-ci notes each watched file's size, modification time and inode,
  and when it fails, a file counts as changed if any of the three differ. A
  time alone is not enough: some file systems keep whole seconds, and `cp -p`
  or a build cache can put an old time back. A log file is read from the size
  it had; one that is now shorter was truncated or rotated, so it is read from
  its start, and the fact `truncated` says so.
- Stages share a slot at the same time: lint and build run side by side, and
  the slow suite runs beside the fast suite. A log file written during the fast
  suite may hold the slow suite's lines too, and a JUnit directory the other
  suite's reports. fun-ci can't untangle that, so it says so: the fact
  `alongside` names each other stage of the run that was running at any moment
  between this stage's start and its failure, and every stage script gets
  `FUN_CI_STAGE`, so a project can send each stage's logs to a file of its own.
- A stage that is cancelled keeps no evidence, since a cancel is not a failure.

`fun-ci extract` (below) is the one place that reads the developer's own
directory, uncommitted files and all, since trying an extractor out is what it
is for.

## How it fits together

```
stage starts: presets whose marker files exist become candidates,
              and the sizes of the files they watch are noted
        |
stage fails or overruns
        |  (overrun only) entries with `on: overrun` run before the kill
        v
  the stage's directory: the output window, reports, watched files' sizes
        |
        v
  test-reports and output-tail, always, outside the budget
        |
        v
  one scan of the output for the candidates' signatures
        |
        v
  the configured entries, then the detected presets, within the budget
        |
        v
  the evidence: chosen, facts, failures, excerpts, problems
        |
        v
  masking of secrets, then caps on size
        |
        v
  stage_jobs row: the evidence; a file in the state directory: the raw output
        |
        +--> fun-ci why [--json] [--raw]     everything
        +--> fun-ci status / wait            the digest, ending with the why command
```

## Extractors

An extractor takes the context of a failed stage and answers what it found:
facts (a name and a value, such as the process that was running at the kill),
failures (a test, its place, its message and its own output), and excerpts (a
titled run of lines from a named place, such as `output:340-372` or
`log/test.log:1204-1260`). Each item carries `extractor`, the name of the entry
that found it: `test-reports`, `section:rspec`, `run:.fun-ci/evidence/x`.

Inside fun-ci this is a Ruby interface, one method that takes an
`Evidence::Context` and answers an `Evidence::Findings`, and the built-in
extractors are Ruby classes behind it. Each built-in declares the options it
takes, so `fun-ci check` validates an entry by asking the built-in, not a list
kept elsewhere. A project's own extractor is a command, which
`Evidence::Command` adapts to the same interface (see "Your own extractor").

### Built in

| Name | Reads | Keeps |
|---|---|---|
| `output-tail` | the output | its last lines (`lines`, 200 by default) |
| `test-reports` | `FUN_CI_REPORT` | each failure, now with its own `<system-out>` and `<system-err>` from JUnit, or `output` from fun-ci JSON |
| `junit-files` | JUnit XML under the globs given (`target/surefire-reports/*.xml`, `build/test-results/**/*.xml`) | as `test-reports`, from files written during the stage only |
| `section` | the output, or a file | the lines between a start and an end pattern, each match up to a line limit |
| `grep` | the output, or a file | lines matching patterns, with lines of context around each |
| `log-file` | the files under a glob | what was written to them during the stage, filtered by `section` or `grep` options when given, else its last lines |
| `json-log` | the output, or a file | JSON lines at or above a level, each as one line (time, level, logger, message) followed by its stack trace |
| `process-tree` | the stage's process group, before the kill | each process's command and how long it had run; the deepest one as the fact `running` |

The same failure can arrive twice, from `test-reports` and from `junit-files`
(the Gradle and Maven scripts `fun-ci init` writes copy the build's reports
into `FUN_CI_REPORT`, AT-9.8, and existing projects keep those scripts). The
evidence keeps one failure per test, file and line.

A **preset** is a config entry that fun-ci ships, in the shape a project would
write one, plus when it applies (below): `rspec` is `use: section` with rspec's
start and end patterns, and the Rails log preset is `use: log-file` with
`path: log/test.log`. Presets live in one YAML file in the gem
(`lib/fun_ci/evidence/presets.yml`), so adding a stack adds data, not code.
Every preset is pinned by the recorded output of a real failing run of that
tool, which its unit test reads; a preset without such a fixture is not
shipped.

The first presets are for the stacks `fun-ci init` already knows: `rspec` and
`minitest` for Ruby, `gradle` and `maven` for the JVM, the Rails log, and the
`logstash` and `ecs` field names for `json-log`. Then the other popular ones:
`pytest`, `jest`, `go-test`, `cargo-test`, `tsc`, and `pino` and `structlog`.

### Choosing which run

With presets for many stacks, fun-ci can't run them all on every failure:
each reads the whole output window, and some walk files or parse every line as
JSON. So each preset says when it applies, with either or both of:

- **Marker files**, any of which must exist in the worktree: `Gemfile` for
  `rspec` and the Rails log, `build.gradle` or `build.gradle.kts` for `gradle`,
  `pom.xml` for `maven`, `go.mod`, `Cargo.toml`, `pyproject.toml` or
  `setup.cfg`, or a `package.json` whose dependencies name `jest`. They are
  checked when the stage starts, at the commit being tested, which is also when
  the files a candidate watches have their sizes noted. A preset without
  markers is always a candidate.
- **An output signature**, a pattern only that tool prints, which matches
  within one line, such as rspec's rerun lines (`rspec ./spec/...`) or pytest's
  `short test summary info`. When the stage fails, the candidates' signatures
  are joined into one pattern and the window is read once, line by line. A
  line the joined pattern matches is then tried against each candidate's own
  signature, because a joined pattern reports only one of the signatures that
  match at a place, and two overlapping ones would otherwise hide each other.
  A candidate with a signature runs only if it was seen; one without runs on
  its markers alone.

Reading the window once keeps the reads down, but a joined pattern does more
work per byte than any one of its parts, so the cost still grows with the
number of candidates, and each preset that runs reads the window again.
Markers keep both to the presets of the stacks the project has. A committed
script (`script/bench-detection.rb`) times the scan over a full window with
every preset a candidate; it is run before the second set of presets ships,
and whenever one is added after.

`output-tail` and `test-reports` always run, and so does `process-tree` for an
overrun. A project's own `run:` commands run only when the config lists them;
fun-ci never guesses at them.

The evidence records what was chosen and why (`"because": "file Gemfile"`,
`"because": "output matched rspec ./"`, `"because": "configured"`), and
`fun-ci check` lists the presets whose markers the project has, so a
developer or an agent can see what will run before anything fails.

**Decision: presets detect themselves; `init` writes no lists.** A list
written by `init` goes stale when the project adds a tool, and misses the
second stack in a repository that has two. Markers cost a handful of file
checks per stage; signatures cost one read of the output.
*Revisit if* the scan shows up in a stage's time: then scan only the last part
of the window.

### When the built-ins aren't enough

A project that needs something the built-ins don't do has three steps up,
each more work than the last: turn a preset on or off; give `section`, `grep`,
`log-file` or `json-log` patterns of its own; or run a command.

### The budget, and what bounds the built-ins

`test-reports` and `output-tail` run first and outside the budget, so the
evidence that works for every stack is there whatever else happens. The
detection scan, the configured entries and the detected presets share the
rest: `evidence.budget`, 2 seconds by default, since it sits between a failed
fast suite and the pre-push hook's verdict.

A command is killed when the budget runs out. A built-in runs in fun-ci's own
process and can't be, so every built-in is given the deadline and checks it as
it goes, every few thousand lines, and stops with what it has, marked
`truncated`. The collector checks it again between extractors. What they read
is bounded too:

- **One window for everything.** The output is kept as its first 1 MB and its
  last 7 MB. Both cuts fall on line ends, and a marker line says how many bytes
  were dropped between them, so no line, and no secret on it, is split (unless
  one line is longer than the window). The window holds at most one chunk of
  output in memory as it goes. Extractors read the window, and the raw output
  kept for `why --raw` is the same window, so
  `fun-ci why --raw > f; fun-ci extract fast --output f` gives the extractors
  that read the output exactly what they saw. A file is read the same way:
  from its start size, or its start, through the same window.
- **Each pattern has its own timeout.** Every pattern a project or a preset
  supplies is compiled with `Regexp.new(source, timeout:)` (Ruby 3.2 and
  later), not under the process-wide `Regexp.timeout`, because stages run in
  threads side by side. The timeout bounds each match, not an extractor's
  whole run, which is why the deadline is checked inside the loop as well. A
  pattern that times out becomes a problem recorded against its entry.

## Configuration

Most projects need no configuration. When one does, it goes in
`.fun-ci/config`, the YAML file that already holds `worktree_slots`:

```yaml
worktree_slots: 2
evidence:
  budget: 2s
  detect: true
  skip: [pino]
  mask: ["ACME-[0-9a-f]{32}"]
  stages:
    all:
      - use: grep
        patterns: ["FATAL", "Segmentation fault"]
        context: 3
    fast:
      - use: log-file
        path: log/payments.log
        grep: ["ERROR"]
        context: 5
    slow:
      - run: .fun-ci/evidence/gradle-problems
        format: json
        watch: ["build/reports/problems/*"]
      - run: pkill -QUIT -g "$FUN_CI_PGID" java
        on: overrun
```

- Settings sit directly under `evidence`; the lists sit under `stages`, one per
  stage, with `all` for every stage, running first.
- Each entry is a mapping with `use:` (a built-in) or `run:` (a command), and
  the options it takes. `on: overrun` makes it run before the kill of a stage
  that ran out of time, instead of after a failure.
- The evidence is shown in this order: `test-reports`, the configured entries,
  the detected presets, then `output-tail`. That is also the order the digest
  looks in.
- `skip` names presets not to run even when detected, `detect: false` turns
  detection off, `mask` adds patterns to mask, and `masking: false` turns
  masking off for the project.
- `fun-ci check` reports an unknown name, an option the extractor doesn't take,
  a pattern that doesn't compile, and a `run:` path that doesn't exist or isn't
  executable, in the same place it reports a missing stage script.
- A mistake found at run time never fails the stage. The entry with the mistake
  is left out and recorded as a problem, which `why` prints; the others run.

## Your own extractor

A `run:` entry is a command, run the way stage scripts are, through the same
`ProcessRunner`: in the worktree slot, with the clean git environment, in a
process group of its own, killed with everything it started if it outruns what
is left of the budget. Its stdin is a file in the stage's directory holding
the context:

```json
{
  "schema": 1,
  "stage": "fast",
  "state": "failed",
  "exit_status": 1,
  "signal": null,
  "seconds": 8.4,
  "budget": 10,
  "alongside": ["slow"],
  "commit": { "sha": "3f9c2ab...", "branch": "main" },
  "worktree": "/path/.git/fun-ci/worktrees/slot-1",
  "started_at": "2026-09-27T14:02:11.402Z",
  "output": "/tmp/fun-ci-stage-x/output.log",
  "reports": "/tmp/fun-ci-stage-x/reports",
  "changed": ["build/test-results/test/TEST-FooTest.xml"],
  "watched": [{ "path": "log/test.log", "offset": 1048576 }],
  "options": {}
}
```

`changed` lists the files under the entry's `watch` globs that were written
during the stage, and `watched` gives, for each file under them that existed
before, the size it had when the stage started, so the extractor can read
only what was appended. fun-ci looks only where `watch` says, because walking a
whole worktree (`node_modules`, `target/`) would cost more than the budget.
`options` holds whatever else the entry said, so one script can serve several
stages. An entry with `on: overrun` also gets the stage's process group, still
running, as `pgid` in the context and `FUN_CI_PGID` in its environment, for
tools such as `jcmd`, `py-spy dump` or `rbspy`, or the one-line JVM thread dump
in the example above.

Its stdout is read up to 256 KB, the cap on the whole evidence; past that the
command is killed and the overflow recorded as a problem. A command that
starts a process which leaves its process group (`setsid`) can't be killed
with it, as with stage scripts today; fun-ci stops reading its output when the
budget and the drain after a kill are over, so such a process can't hold the
evidence up, and whatever it does afterwards is not fun-ci's to see.

What it prints depends on `format`:

- `text` (the default) takes stdout as one excerpt, titled with the command.
  This makes a one-liner an extractor: `run: grep -B2 -A20 "Caused by" build/test.log`.
- `json` takes stdout as one document, with any of the lists the evidence has:

```json
{
  "schema": 1,
  "facts": [{ "name": "module", "value": "core" }],
  "failures": [{ "test": "OrderTest#totals", "file": "src/test/OrderTest.kt", "line": 42,
                 "message": "expected 3 but was 2", "output": "..." }],
  "excerpts": [{ "title": "Gradle problems report", "location": "build/reports/problems.html",
                 "lines": ["..."] }]
}
```

An exit status other than 0, a document that doesn't parse, or a field of the
wrong type is recorded as a problem with the entry's name and the last 20
lines of its stderr. Nothing it printed is kept then. A field fun-ci doesn't
know is ignored, so an extractor that adds fields still works. A document
with a `schema` higher than fun-ci knows is a problem, since its fields may
mean something else.

To write or change an extractor without making a commit, `fun-ci extract`
runs a stage's extractors against a saved output:

```bash
fun-ci extract fast --output failing-run.log [--reports DIR] [--exit 1 | --timed-out] [--json]
```

It uses the current directory as the worktree, touches no database, and prints
what `why` would print, problems included. An agent can save a failing run's
output once (`fun-ci why --raw`) and iterate on an extractor against it. Two
things differ from a real failure, and `extract` says both as facts: there
were no start sizes, so files are read whole and every watched file counts as
changed; and with `--timed-out` there is no process group, so entries with
`on: overrun` don't run.

**Decision: a project's extractor is a command, not a Ruby class.** The
request was for a strategy class a project could provide. fun-ci's users are
on any stack, and the way a project already extends fun-ci is an executable
(its four stage scripts), so a Kotlin or Python team would otherwise have to
write Ruby, against fun-ci's internal classes, loaded into the process that
records the run. A command can be written in the project's own language, can
be killed when it overruns (a Ruby thread can't be, safely), can't crash the
trigger or inherit its SQLite connection, and depends on a versioned JSON
document rather than on fun-ci's class names, which is the reason the
renderer is a separate process too. The cost is a process per extractor:
milliseconds, except the first run of a freshly written executable on macOS,
which the system scans (130 to 250 ms, measured for stage scripts; see the
Gotchas in `CLAUDE.md`).
*Revisit if* Ruby projects ask for in-process extractors often enough to be
worth a second mechanism; even then, run them in a child Ruby.

## What `why` prints

`fun-ci why [REV] [STAGE] [--json] [--raw]`:

- Without STAGE, the first needed stage to fail or overrun, in the order they
  finished, as the verdict takes it; `--need` works as for `status`.
- The text form: one line naming the stage, its state, exit status or signal,
  time and budget; the facts; each failure in full, with its own output under
  it; each excerpt under its title and location; the problems, each naming its
  entry; and, when the raw output is kept, the command that prints it.
- `--raw` prints the kept raw output, masked, and nothing else.
- When the only evidence is the output's last lines, `why` ends by saying so
  and naming the setting that adds more (`evidence:` in `.fun-ci/config`). An
  agent that reads that line can write the extractor itself.
- The exit code is the verdict, as `status` gives it, so a code means the same
  thing across `status`, `wait` and `why`.

`--json` prints one document, whatever the case:

```json
{
  "schema": 1,
  "commit": { "sha": "3f9c2ab...", "branch": "main", "subject": "..." },
  "stage": "fast",
  "state": "failed",
  "exit_status": 1,
  "signal": null,
  "seconds": 8.4,
  "budget": 10,
  "evidence": {
    "chosen": [{ "extractor": "section:rspec", "because": "output matched rspec ./" }],
    "facts": [{ "name": "alongside", "value": "slow", "extractor": "fun-ci" }],
    "failures": [{ "test": "...", "file": "...", "line": 42, "message": "...", "output": "...",
                   "extractor": "test-reports" }],
    "excerpts": [{ "title": "rspec failures", "location": "output:340-372", "lines": ["..."],
                   "truncated": false, "extractor": "section:rspec" }],
    "problems": [{ "extractor": "run:.fun-ci/evidence/gradle-problems", "message": "exited 2: ..." }]
  },
  "no_evidence": null,
  "raw_output": { "kept": true, "bytes": 1843200 }
}
```

`state` uses the words `status --json` uses (`failed`, `over_budget`,
`passed`, `running`, `cancelled`). When there is no evidence, `evidence` is
null and `no_evidence` says why: `pruned` (only a project's 50 newest runs keep
it), `passed`, `running` or `cancelled`. Like the other JSON fun-ci prints, this
is a contract: a field, once published, keeps its name, and a change that
isn't additive raises `schema`.

The digest `status` and `wait` print stays as short as today, now drawn from
the evidence: the failures (at most 10, 5 lines of each message), or else the
first excerpt in the order above (at most 20 lines), or else the output's last
20 lines; for an overrun, the `running` fact first
(`fast ran over budget: running java ... GradleWorkerMain (9.8s)`). It ends
with the command that shows the rest: `fun-ci why 3f9c2ab fast`.

## Masking secrets

A stage's output and its log files can hold secrets, and the evidence is kept,
printed to agents, and pasted into places. Before anything is stored, every
string in the evidence, the problems (a command's stderr included) and the raw
output is masked:

- the value of each variable in the stage's environment whose name contains
  `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `API_KEY`, `PRIVATE_KEY` or
  `CREDENTIAL`, when the value is at least 8 characters, becomes
  `[masked:NAME]`; longer values are replaced first, so one that contains
  another is masked whole;
- well-known token shapes (GitHub, AWS access key IDs, Slack, PEM private key
  blocks, `Authorization:` headers) become `[masked]`;
- the patterns in `evidence.mask` become `[masked]`.

The masker is given the stage's environment as a hash, never reads `ENV`, so
its tests say what is in the environment. Masking is on by default and can be
turned off only for a whole project. It is a best effort, not a guarantee, so
what is unmasked stays where only the user can read it:

- The state directory is 0700. Today `StateDir` doesn't set a mode, so the
  directory and database get whatever the umask gives, typically readable by
  other local users [inferred from Ruby's defaults, not measured]; fun-ci sets
  the mode when it opens the directory, including one that already exists.
- The window is written unmasked while the stage runs, so each stage's
  directory lives in the state directory, not in `TMPDIR`, named for the
  process that made it. It is removed when the stage is recorded; a run that
  starts removes those whose process is dead, which is what a crash leaves.

## Overruns

A killed stage's last lines rarely say what it was stuck on. So when a stage
reaches its budget, fun-ci runs `process-tree` and the entries with
`on: overrun` first, while the process group is still alive, then kills it and
collects the rest as for any failure. `process-tree` lists the group's
processes, and the deepest one still running is the fact `running`, which the
digest leads with. It reads `ps -A -o pid,pgid,etime,command`, which BSD and
procps both take, and picks the group in Ruby; whether busybox `ps` on the
musl target takes it too is not yet checked.

What an overrun entry makes the stage print, such as a JVM's thread dump
after `SIGQUIT`, goes into the window like the rest of the output, since the
stage's output is still being read. A stage that exits during these seconds is
still `over_budget`: its budget ran out before it did.

**Decision: overrun extractors get 2 seconds beyond the budget.** A killed
stage has already lost its verdict, and the pre-push hook waits on it, so the
wait grows by at most 2 seconds, once, for a stage that blew its budget. That
is the price of finding out what it was doing without running it again.
*Revisit if* a common stack needs longer to dump its state.

A built-in JVM thread dump was considered and left out: it needs a JVM in CI
to test, and the one-line `run:` entry in the configuration example does the
same.

## Storage and retention

| What | Where | Size | Kept for |
|---|---|---|---|
| The evidence | `stage_jobs.evidence`, JSON | at most 256 KB per stage | a project's 50 newest runs, as the output tail is today |
| The raw output | a file per stage in the state directory, zlib-compressed | the 8 MB window | a project's 10 newest runs |

The evidence is stored without the stage's name, state, times, budget, exit
status or whether the raw output is still kept: those come from the stage row
and the state directory when `why` reads them, so nothing stored can go stale.
`stage_jobs` gains `exit_status`, `signal` and `budget` for that.

The raw output is a file, not a blob, because SQLite doesn't give the space of
deleted rows back to the file system without a `VACUUM`, and one database
holds every project on the machine. Pruning a run deletes its files. Keeping
it answers the question of how much output to keep: the extractors choose what
is worth reading, and the raw output is there for when they chose wrong, so
an agent never reruns a suite because an extractor missed something. The worst
case is two failed stages in each of a project's 10 newest runs (a run fails at
most lint and build, or fast and slow, since the second pair runs only when the
first passes), each with a full window: 160 MB before compression.

Each failure's own output is kept as its last 4 KB, always. The 256 KB cap is
there because `why` prints the evidence whole into an agent's context. Over
it, excerpts are cut from the last in the order above backwards, then messages
to 50 lines each, each cut marked `truncated`; facts and problems are small and
never cut. At most 100 failures are kept in full, and the rest are counted in a fact.
The caps are one class (`Evidence::Caps`) apart from the merging.

The `failures` and `output_tail` columns stay filled in as they are today,
because every project on a machine shares one database, and an older fun-ci in
another project reads the same rows. A row written before this change has
no evidence, budget or exit status, and `why` shows what it has: the tail and
the failures, as §9 does.

Pruning deletes the raw output files of the runs it drops, and any file in
the raw output directory whose stage row no longer exists, which is what a
crash between the two leaves.

## Changes to what exists

- **One path for a failed stage.** `StageRunner` and `BackgroundWrapper` both
  hand a failed stage to the same code, which runs the extractors, masks,
  caps and records, before the stage's state is recorded, as today.
- **Output goes to a window on disk, not memory.** `ProcessRunner` now appends
  every byte a stage prints to one `String` for as long as it runs, so a stage
  that prints without limit grows fun-ci's memory without limit [read from
  `process_runner.rb`; not measured]. The output is written instead to the
  window file in a per-stage directory (`Pipeline::StageDir`, which also holds
  the reports directory `ReportDir` is today and the watched files' sizes).
  `CommandExecutor` answers an `Output` value in place of a string, with an
  in-memory version that injected command runners keep returning, so the
  fakes tests use don't change. The pre-push hook's echo of a failed stage's
  output reads the window's end.
- **`Launch` carries the new inputs.** `run_process_with_timeout` already takes
  four parameters, so the hook that runs overrun extractors before the kill,
  and the stdin file a command extractor reads, go on `Launch` rather than in
  new parameters.
- **Stage scripts get `FUN_CI_STAGE`.**
- **New seams**, each left out getting the real thing, as with the others:
  `clock` on `Seams`, which the budget, the deadline and the overrun grace
  read; `process_table`, which answers what `ps` would, so `process-tree` runs
  in the acceptance lane; `environment`, the stage's environment as a hash,
  which the masker and fake runners see; and `extractor_runner`, which runs
  `run:` entries, so the fake stage runners tests have never receive an
  extractor's command. `ProcessRunner` already has `timer:`, which declares an
  overrun at once, and the grace, the window's sizes and each pattern's timeout
  are arguments, so tests use milliseconds and kilobytes.
- `OutputTail` and `TestReport` become the `output-tail` and `test-reports`
  built-ins.
- `Agent::Evidence`, which prints the digest today, is renamed
  `Agent::Digest`, so `FunCi::Evidence` can name the new module.

New code, in `lib/fun_ci/evidence/`: `Context`, `Findings`, `Document`
(merging, and one failure per test), `Caps`, `Collector` (the order, the
deadline between extractors, anything an extractor raises becoming a
problem), `Catalog` (built-in names, each with the options it takes),
`presets.yml` and `Detection`, `Command` (the `run:` adapter), `Masking`, one
file per built-in, and `Settings` for the `evidence` key of `.fun-ci/config`.

## Testing it

The acceptance tests in §10 each pin one thing through a command, with one
case; the cases around it are pinned by the class that decides them.

- **Unit, one class in memory.** Each built-in over recorded fixtures (below).
  `Masking`: each kind of secret, the longest first, 7 against 8 characters, a
  command's stderr. `Window`: the cuts on line ends, the marker, and never
  more than one chunk held. `Detection`: candidates by marker, signatures
  (joined detection gives the same presets as each signature tried alone, as
  a property over generated lines), and that the window is read once, with a
  counting reader. `Collector`: the order, a raising extractor becoming a
  problem, the deadline exactly at its edge and inside a built-in's loop.
  `Command`'s arithmetic, with a fake runner that records the budget it was
  given. `Caps`, `Document` (one failure per test), `Catalog` and `Settings`
  (every kind of mistake `check` reports). `process-tree` parsing recorded
  `ps` listings from BSD and procps.
- **Properties.** No property-testing gem is in the Gemfile, so generators are
  hand-rolled on a seeded `Random` and print their seed on failure. Two
  properties: every built-in, given arbitrary bytes (invalid UTF-8, colour
  codes, no newline at the end), answers findings and never raises; and no
  secret's value survives anywhere in the evidence or the raw output. Inputs
  stay small; one fixed case with a megabyte-long line covers length.
- **Integration.** The state directory's mode, with a permissive umask set by
  the test and a directory that already exists at 0755; a row written before
  the migration; raw output files pruned with their runs, orphans too, and the
  10th against the 11th newest run; the `output_tail` and `failures` columns
  still written.
- **Process lane.** `Command` with shell-script extractors: text and JSON, a
  bad exit, bad JSON, a higher schema, stdout past 256 KB, one that outruns
  its budget and is killed with what it started, and one whose child escapes
  with `setsid` and keeps stdout open, which must not hold the evidence past
  the budget and the drain. The window at its real sizes, from about 10 MB of
  `head -c` output. `process-tree` against the real `ps` of the CI machine.
  An overrun through `ProcessRunner`'s `timer:`: the entry runs before the
  kill, what it makes the stage print is kept, and a stage that exits during
  the grace is still over budget. `FUN_CI_STAGE`.
- **The regexp timeout test** needs a pattern that backtracks on every Ruby in
  CI: Ruby 3.2 and later memoise the classic `^(a+)+$`, which then never times
  out, while `^(a+)+\1$` does (on Ruby 4.0.2, 40 `a`s and a
  `!`: the first returns at once, the second times out; check on 3.2 with
  `script/ci-matrix.sh` before relying on it).
- **Mutation.** The code that runs only in the slow suite's forked child shows
  as no coverage, so the shared path for a failed stage is tested in the
  foreground, where mutants can be killed.
- **End to end.** One test fails a real slow suite whose cause is only in a log
  file, and reads it back through `fun-ci why`.

### Fixtures

A preset is only as good as the output it was checked against, so fixtures are
recorded, not written:

- `script/record-evidence-fixture TOOL` runs a minimal failing project for
  that tool in a pinned Docker image, stdout and stderr merged through a pipe
  as a stage's are, and writes the output and a `meta.yml` beside it: the
  tool and its version, the image digest, the command, the script's commit,
  and the output's SHA-256.
- A policy test holds that every preset has a fixture, that each output
  matches its hash, and that each expected excerpt is a range of the output's
  own lines, so an expectation can't be made up. A hash shows an edit; it
  doesn't stop one.
- A cross test runs every signature against every other tool's fixture, which
  none may match. It is what notices a bad edit to `presets.yml`, which no
  mutation tool reads.
- A scheduled CI job, outside the gate, records each fixture again with the
  tool's latest version and reports any difference in what its preset picks
  out.
- The protocol's contract fixtures in `contract/evidence/` go both ways: Ruby
  writes the context for a known stage and it must equal the input fixture;
  the sample extractor is a shell script, so Ruby isn't checking itself; and
  there are fixtures with unknown fields and with a higher schema.

## Order of work

The requirements are AT-10.1 to AT-10.20, in the order they are built.
`why` comes first, over the evidence §9 already keeps, then the digest's
pointer to it. Masking comes next, so it is in place before fun-ci keeps more
than it keeps today, then the window and `why --raw`: once an agent has the
raw output, it can search it itself. Then `FUN_CI_STAGE`, configuration, the
first presets, log files, the stage alongside, JSON logs, each failure's own
output, commands, `extract`, overruns, and detection, once there are presets
to detect. The presets for the other popular stacks come last.
