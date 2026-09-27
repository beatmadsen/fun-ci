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
  a report directory can hold a previous run's content. Extractors that read
  files are told which files changed during the stage, and log files are read
  from the size they had when the stage started.
- Stages share a slot at the same time: lint and build run side by side, and
  the slow suite runs beside the fast suite. A log file written during the fast
  suite may hold the slow suite's lines too, and a JUnit directory the other
  suite's reports. fun-ci can't untangle that, so it says so: the evidence
  records which other stage was running (the fact `alongside`), and every stage
  script gets `FUN_CI_STAGE`, so a project can send each stage's logs to a file
  of its own.
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
- **An output signature**, a pattern only that tool prints, such as rspec's
  rerun lines (`rspec ./spec/...`) or pytest's `short test summary info`. When
  the stage fails, the candidates' signatures are joined into one pattern and
  the output is read once. A candidate with a signature runs only if it was
  seen; one without runs on its markers alone.

Reading the output once keeps the reads down, but a joined pattern does more
work per byte than any one of its parts, so the cost still grows with the
number of candidates. Markers keep that number to the presets of the stacks
the project has. How fast the scan is, over the whole window with every
preset a candidate, is measured before the second set of presets ships.

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
configured entries and detected presets share the rest: `evidence.budget`,
2 seconds by default, since it sits between a failed fast suite and the
pre-push hook's verdict.

A command is killed when the budget runs out. A built-in runs in fun-ci's own
process and can't be, so the collector checks the deadline between extractors,
and the built-ins are bounded by what they read:

- **One window for everything.** The output is kept as its first 1 MB and its
  last 7 MB, with a marker line where bytes were dropped. Extractors read that
  window, and the raw output kept for `why --raw` is the same window, so
  `fun-ci why --raw > f; fun-ci extract fast --output f` reproduces exactly
  what the extractors saw. A file is read the same way: from its start size, or
  its start, through the same window.
- **Each pattern has its own timeout.** Every pattern a project or a preset
  supplies is compiled with `Regexp.new(source, timeout:)` (Ruby 3.2 and
  later), not under the process-wide `Regexp.timeout`, because stages run in
  threads side by side. A pattern that backtracks badly becomes a problem
  recorded against its entry, not a hung pipeline.

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
know is ignored, so an extractor written against a later schema still works.

To write or change an extractor without making a commit, `fun-ci extract`
runs a stage's extractors against a saved output:

```bash
fun-ci extract fast --output failing-run.log [--reports DIR] [--exit 1 | --timed-out] [--json]
```

It uses the current directory as the worktree, touches no database, and prints
what `why` would print, problems included. An agent can save a failing run's
output once (`fun-ci why --raw`) and iterate on an extractor against it.

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
string in the evidence and the raw output is masked:

- the value of each variable in the stage's environment whose name contains
  `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `API_KEY`, `PRIVATE_KEY` or
  `CREDENTIAL`, when the value is at least 8 characters, becomes
  `[masked:NAME]`;
- well-known token shapes (GitHub, AWS access key IDs, Slack, PEM private key
  blocks, `Authorization:` headers) become `[masked]`;
- the patterns in `evidence.mask` become `[masked]`.

The masker is given the stage's environment as a hash, never reads `ENV`, so
its tests say what is in the environment. Masking is on by default and can be
turned off only for a whole project. It is a best effort, not a guarantee, so
the state directory is also created readable by its owner only (0700). Today
`StateDir` doesn't set a mode, so the directory and database get whatever the
umask gives, typically readable by other local users [inferred from Ruby's
defaults, not measured].

## Overruns

A killed stage's last lines rarely say what it was stuck on. So when a stage
reaches its budget, fun-ci runs `process-tree` and the entries with
`on: overrun` first, while the process group is still alive, then kills it and
collects the rest as for any failure. `process-tree` lists the group's
processes, and the deepest one still running is the fact `running`, which the
digest leads with.

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

The 256 KB cap is there because `why` prints the evidence whole into an
agent's context. Over it, excerpts are cut from the last in the order above
backwards, then each failure's `output` to its last 4 KB, then messages to 50
lines each, each cut marked `truncated`; facts and problems are small and never
cut. At most 100 failures are kept in full, and the rest are counted in a fact.
The caps are one class (`Evidence::Caps`) apart from the merging.

The `failures` and `output_tail` columns stay filled in as they are today,
because every project on a machine shares one database, and an older fun-ci in
another project reads the same rows.

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

- Each built-in and each preset is a unit test over recorded output: a real
  failing run of that tool, saved under `test/fixtures/evidence/<tool>/`, with
  the excerpt it must pick out. A preset is shipped with its fixture or not at
  all.
- A property test feeds every built-in arbitrary bytes (invalid UTF-8, colour
  codes, lines of a megabyte, no newline at the end) and holds that it answers
  findings and never raises.
- Detection is a unit test over a worktree fixture and an output: which
  presets become candidates, which run, and that the output is read once
  whatever the number of presets (a counting reader, not a timer). How fast
  the joined pattern is gets measured by a script, not asserted in a test.
- `Collector`, `Document` and `Caps` are unit tests with fake extractors and the
  clock seam: order, the deadline checked between extractors, caps, a raising
  extractor becoming a problem.
- `process-tree` parses a recorded `ps` listing in a unit test; only the call
  that reads the real process group is in the process lane.
- `Command` lives in the process lane, with shell-script extractors: text and
  JSON forms, a bad exit, bad JSON, one that outruns its budget and is killed
  along with what it started.
- The extractor protocol has contract fixtures, input and output documents in
  `contract/evidence/`, which the Ruby side parses and which a sample
  extractor, used in the process tests, answers from.
- `why`, `extract` and the digest are acceptance tests through the agent
  client, with evidence written through the recorder.
- One end-to-end test fails a real slow suite whose cause is only in a log
  file, and reads it back through `fun-ci why`.

## Order of work

The requirements are AT-10.1 to AT-10.18, in the order they are built.
`why` comes first, over the evidence §9 already keeps, then the digest's
pointer to it. Next come the window, masking and the raw output: once an agent
has `why --raw`, it can search the output itself, and masking is in place
before fun-ci keeps more than it keeps today. Then configuration, the
built-ins with the first presets, log files, JSON logs, each failure's own
output, commands, `extract`, overruns, and detection, once there are presets
to detect. The presets for the other popular stacks come last.
