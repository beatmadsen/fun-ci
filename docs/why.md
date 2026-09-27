# fun-ci why, and the extractors that find the evidence

The design of `fun-ci why` and of what it reads: evidence about a failed stage,
picked out at the moment the stage fails by extractors that a project can
configure, and replace with its own. This file is a plan. The requirements are
in [`acceptance-tests.md`](acceptance-tests.md), §10, and once they are built,
the decisions below move into [`architecture.md`](architecture.md), what the
developer sees moves into [`design.md`](design.md), and this file goes.

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

fun-ci can't know every stack and every logging setup. So the design is a
small set of built-in extractors that cover the common cases, configured per
stage, and a way for a project to add its own, in whatever language it
already uses.

## Goals

1. `fun-ci why` shows everything fun-ci kept about a failed stage, and an agent
   rarely needs more.
2. Collecting it never changes a stage's verdict, and never holds a verdict up
   by more than a small, fixed budget.
3. A project whose failures don't fit the built-in extractors can fix that in
   its own repository, with a line of config or a script, and try the change
   without making a commit.
4. With no configuration, fun-ci behaves as it does today.

Not goals: keeping build artefacts (screenshots, coverage, binaries), which the
Local principle in `design.md` rules out; reading anything from uncommitted
files; and interpreting a failure (saying *what* is wrong with the code), which
is the agent's job.

## Where evidence can come from

At the moment a stage fails, and only then, all of these are available:

| Source | What it holds | How long it lasts |
|---|---|---|
| The stage's output | stdout and stderr, as one stream in the order printed | in fun-ci's hands until the stage is recorded |
| `FUN_CI_REPORT` | the test reports the stage wrote | removed when the stage is recorded |
| The worktree slot | log files, crash files, reports the build tool wrote in its own place | until the next run takes the slot |
| The stage's process group | for an overrun, the processes still running, before the kill | until the kill |
| The run itself | stage, outcome, exit status or signal, duration, budget, commit | kept in the database |

Almost all of it is gone within seconds. That is why extraction happens in the
stage runner, while the stage still holds its slot, before its outcome is
recorded: the same place `StageRunner#keep_evidence` runs today.

Two traps come with the worktree slot. Slots are reused, and `git clean -fd`
keeps ignored files, so a log file or a report directory can hold a previous
run's content. Extractors that read files are therefore told which files
changed during the stage, and log files are read from the size they had when
the stage started.

## How it fits together

```
stage fails or overruns
        |
        |  (overrun only) overrun extractors run before the kill
        v
  the stage's directory: output spool, reports, watched files' start sizes
        |
        v
  extractors, in the order configured for the stage, within the budget
        |
        v
  one evidence document: facts, failures, excerpts, problems
        |
        v
  masking of secrets, then caps on size
        |
        v
  stage_jobs row: the document, plus the raw output (compressed)
        |
        +--> fun-ci why [--json] [--raw]     everything
        +--> fun-ci status / wait            the digest, ending with the why command
```

## Extractors

An extractor takes the context of a failed stage and answers what it found:
facts (a name and a value, such as the process that was running at the kill),
failures (a test, its place, its message and its own output), and excerpts (a
titled run of lines from a named place, such as `output:340-372` or
`log/test.log:1204-1260`). Each item carries the name of the extractor that
found it.

Inside fun-ci this is a Ruby interface, one method that takes an
`Evidence::Context` and answers an `Evidence::Findings`, and the built-in
extractors are Ruby classes behind it. A project's own extractor is a command,
which `Evidence::Command` adapts to the same interface (see "Your own
extractor" below).

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
| `jvm-thread-dump` | Java processes in the stage's process group, before the kill | a thread dump (SIGQUIT), which lands in the output the stage is already capturing |

`section` and `grep` carry most of the stack knowledge, as data. A **preset**
is a named set of their options for one tool, such as `preset: rspec`,
`preset: gradle`, `preset: pytest`, `preset: go-test`, `preset: cargo-test`,
`preset: jest` or `preset: tsc`. `json-log` has presets for the field names of
common appenders (`logstash`, `ecs`, `pino`, `structlog`). Every preset is
pinned by the recorded output of a real failing run of that tool, which its
unit test reads; a preset without such a fixture is not shipped.

A project that needs something the built-ins don't do has three steps up,
each more work than the last: use a preset; give `section`, `grep` or
`json-log` patterns of its own; or run a command.

Built-ins run in the stage runner's process, so they can't be killed. They
are kept inside the budget by what they read instead: at most the spooled
output (see "Changes to what exists") and at most 8 MB of any one file, and
every pattern a project supplies is matched under `Regexp.timeout`
(Ruby 3.2 and later), so a pattern that backtracks badly becomes a problem
recorded against that extractor, not a hung pipeline.

## Configuration

Extractors are configured in `.fun-ci/config`, the YAML file that already
holds `worktree_slots`, as a list per stage. `all` applies to every stage and
runs first.

```yaml
worktree_slots: 2
evidence:
  budget: 5s
  all:
    - use: output-tail
  fast:
    - use: test-reports
    - use: section
      preset: rspec
    - use: log-file
      path: log/test.log
      grep: ["ERROR", "FATAL"]
      context: 5
    - use: json-log
      from: output
      preset: logstash
      level: warn
  slow:
    - use: junit-files
      paths: ["build/test-results/**/*.xml"]
    - run: .fun-ci/evidence/gradle-problems
      format: json
      watch: ["build/reports/problems/*"]
  overrun:
    - use: process-tree
    - use: jvm-thread-dump
```

- Each entry is a mapping with `use:` (a built-in) or `run:` (a command), and
  the options it takes. Order is the order of the evidence, and decides what
  the digest shows first.
- With no `evidence` key, every stage gets `test-reports` then `output-tail`,
  and an overrun gets `process-tree`: today's behaviour, plus the process
  tree.
- `fun-ci init` writes the list for the stack it detects (the Gradle and Maven
  lists read their own report directories, so the copying that AT-9.8 put in
  their stage scripts can go).
- `fun-ci check` reports an unknown name, an option the extractor doesn't take,
  a pattern that doesn't compile, and a `run:` path that doesn't exist or isn't
  executable, in the same place it reports a missing stage script.
- A mistake found at run time never fails the stage. fun-ci falls back to the
  default list for that stage and records the mistake as a problem, which
  `why` prints.

## Your own extractor

A `run:` entry is a command, run the way stage scripts are: in the worktree
slot, with the clean git environment, in a process group of its own, killed if
it outruns what is left of the budget. It is given the context as one JSON
document on stdin:

```json
{
  "schema": 1,
  "stage": "fast",
  "outcome": "failed",
  "exit_status": 1,
  "signal": null,
  "seconds": 8.4,
  "budget": 10,
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
only what the stage appended. fun-ci looks only where `watch` says, because
walking a whole worktree (`node_modules`, `target/`) would cost more than the
budget. `options` holds whatever else the entry said, so one script can serve
several stages. An overrun extractor also gets `"pgid"`, the
stage's process group, which is still running.

What it prints depends on `format`:

- `text` (the default) takes stdout as one excerpt, titled with the command.
  This makes a one-liner an extractor: `run: grep -B2 -A20 "Caused by" build/test.log`.
- `json` takes stdout as one document, with any of the three lists the
  evidence document has:

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
wrong type is recorded as a problem with the extractor's name and the last 20
lines of its stderr. Nothing it printed is kept then. A field fun-ci doesn't
know is ignored, so an extractor written against a later schema still works.

To write or change an extractor without making a commit, `fun-ci extract`
runs a stage's configured extractors against a saved output:

```bash
fun-ci extract fast --output failing-run.log [--reports DIR] [--exit 1 | --timed-out] [--json]
```

It uses the current directory as the worktree, touches no database, and prints
what `why` would print, problems included. An agent can capture a failing
run's output once and iterate on an extractor against it.

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

## The evidence document

What extractors find is merged into one document per stage, which is what the
database keeps and what `why --json` prints:

```json
{
  "schema": 1,
  "stage": "fast",
  "outcome": "failed",
  "exit_status": 1,
  "signal": null,
  "seconds": 8.4,
  "budget": 10,
  "facts": [{ "name": "running", "value": "java ... GradleWorkerMain", "source": "process-tree" }],
  "failures": [{ "test": "...", "file": "...", "line": 42, "message": "...", "output": "...",
                 "source": "test-reports" }],
  "excerpts": [{ "title": "rspec failures", "location": "output:340-372", "lines": ["..."],
                 "truncated": false, "source": "section" }],
  "problems": [{ "source": "run: .fun-ci/evidence/gradle-problems", "message": "exited 2: ..." }],
  "raw_output": { "kept": true, "bytes": 1843200 }
}
```

Like the other JSON fun-ci prints, this is a contract: a field, once published,
keeps its name, and a change that isn't additive raises `schema`.

Caps, applied after masking:

- 256 KB per stage for the whole document. Over that, excerpts are cut from the
  last in configured order backwards, then each failure's `output` to its last
  4 KB, then messages to 50 lines each, each cut marked `truncated`. Facts and
  problems are small and never cut.
- 100 failures per stage in full; the rest are counted, in a fact.
- The `failures` and `output_tail` columns stay filled in as they are today,
  because every project on a machine shares one database, and an older fun-ci
  in another project reads the same rows.

## Masking secrets

A stage's output and its log files can hold secrets, and the evidence is kept,
printed to agents, and pasted into places. Before anything is stored, every
string in the document and the raw output is masked:

- the value of each variable in the stage's environment whose name contains
  `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `API_KEY`, `PRIVATE_KEY` or
  `CREDENTIAL`, when the value is at least 8 characters, becomes
  `[masked:NAME]`;
- well-known token shapes (GitHub, AWS access key IDs, Slack, PEM private key
  blocks, `Authorization:` headers) become `[masked]`;
- `evidence.mask` in `.fun-ci/config` adds patterns of the project's own.

Masking is on by default and can't be turned off per stage, only per project
(`evidence.mask: false`). It is a best effort, not a guarantee, so the state
directory is also created readable by its owner only (0700). Today
`StateDir` doesn't set a mode, so the directory and database get whatever the
umask gives, typically readable by other local users [inferred from Ruby's
defaults, not measured].

## Overruns

A killed stage's last lines rarely say what it was stuck on. So when a stage
reaches its budget, fun-ci runs the `overrun` extractors first, while the
process group is still alive, then kills it and runs the stage's own
extractors as for any failure.

- `process-tree` lists the group's processes. Its `running` fact (the deepest
  process still running) is what the digest shows for an overrun:
  `fast ran over budget: running java ... GradleWorkerMain (9.8s)`.
- `jvm-thread-dump` sends SIGQUIT to each Java process in the group. The JVM
  prints a thread dump to its stdout, which the stage is already capturing, so
  the output tail and the excerpts then show where every thread was.
- A `run:` entry under `overrun` gets `pgid`, for tools of the project's own
  (`py-spy dump`, `rbspy`, `jcmd`).

**Decision: overrun extractors get 2 seconds beyond the budget.** A killed
stage has already lost its verdict, and the pre-push hook waits on it, so the
wait grows by at most 2 seconds, once, for a stage that blew its budget. That
is the price of finding out what it was doing without running it again.
*Revisit if* a common stack needs longer to dump its state.

## What the developer and the agent see

`fun-ci why [REV] [STAGE] [--json] [--raw]`:

- Without STAGE, the first needed stage to fail or overrun, in the order they
  finished, as the verdict takes it; `--need` works as for `status`.
- The text form: one line naming the stage, its outcome, exit status or
  signal, time and budget; the facts; each failure in full, with its own
  output under it; each excerpt under its title and location; the problems,
  each naming its extractor; and, when the raw output is kept, the command
  that prints it.
- `--raw` prints the kept raw output instead, masked, and nothing else.
- When the only evidence is the output's last lines, `why` ends by saying so
  and naming the setting that adds more (`evidence:` in `.fun-ci/config`). An
  agent that reads that line can write the extractor itself.
- The exit code is the verdict, as `status` gives it, so a code means the same
  thing across `status`, `wait` and `why`. A run whose evidence was pruned
  still exits with its verdict, says that its evidence is no longer kept (only
  a project's 50 newest runs keep it), and `--json` gives `"evidence": null`
  with `"evidence_gone": "pruned"`. A stage that passed prints that it passed.

The digest `status` and `wait` print stays as short as today, now drawn from
the document: the failures (at most 10, 5 lines of each message), or else the
first excerpt in configured order (at most 20 lines), or else the output's
last 20 lines; for an overrun, the `running` fact first. It ends with the
command that shows the rest: `fun-ci why 3f9c2ab fast`.

## Storage and retention

| What | Per stage | Kept for |
|---|---|---|
| The evidence document | at most 256 KB | a project's 50 newest runs, as the output tail is today |
| The raw output | the first 1 MB and last 7 MB of what the stage printed, zlib-compressed | a project's 10 newest runs |

Keeping the raw output answers the open question of how much to keep. The
extractors choose what is worth reading; the raw output is there for when they
chose wrong, so an agent never has to rerun a suite because an extractor
missed something. Only failed and over-budget stages keep either, and Ruby's
`zlib` is in the standard library, so no dependency is added. The worst case is
two failed stages in each of a project's 10 newest runs (a run fails at most
lint and build, or fast and slow, since the second pair runs only when the
first passes), each with 8 MB of output: 160 MB before compression.

## Changes to what exists

- **Output goes to a file, not memory.** `ProcessRunner` now appends every
  byte a stage prints to one `String` for as long as it runs, so a stage that
  prints without limit grows fun-ci's memory without limit [read from
  `process_runner.rb`; not measured]. The stage's output is spooled instead to
  a file in a per-stage directory (`Pipeline::StageDir`, which also holds the
  reports directory `ReportDir` is today, and the start sizes of watched
  files), keeping the first 1 MB and a rolling last 63 MB, with a marker where
  bytes were dropped. Extractors read that file; the pre-push hook's echo of a
  failed stage's output reads its tail.
- `OutputTail` and `TestReport` become the `output-tail` and `test-reports`
  built-ins.
- `Agent::Evidence`, which prints the digest today, is renamed
  `Agent::Digest`, so `FunCi::Evidence` can name the new module.
- `stage_jobs` gains `evidence` (the document, as JSON) and `raw_output` (a
  blob), added the way `output_tail` and `failures` were.
- `StageRunner#keep_evidence` calls the collector instead of keeping the tail
  and the failures itself. The order holds: evidence first, then the outcome,
  so whoever sees the outcome can read why.

New code, in `lib/fun_ci/evidence/`: `Context`, `Findings`, `Document` (merge,
caps, schema), `Collector` (runs a stage's list within its budget, turning
anything an extractor raises into a problem), `Catalog` (built-in names),
`Presets`, `Command` (the `run:` adapter), `Masking`, one file per built-in,
and `Settings` for the `evidence` key of `.fun-ci/config`.

## Testing it

- Each built-in and each preset is a unit test over recorded output: a real
  failing run of that tool, saved under `test/fixtures/evidence/<tool>/`, with
  the excerpt it must pick out. A preset is shipped with its fixture or not at
  all.
- A property test feeds every built-in arbitrary bytes (invalid UTF-8, colour
  codes, lines of a megabyte, no newline at the end) and holds that it answers
  findings and never raises.
- `Collector` and `Document` are unit tests with fake extractors and the clock
  seam: order, budget, caps, a raising extractor becoming a problem.
- `Command` lives in the process lane, with shell-script extractors: text and
  JSON forms, a bad exit, bad JSON, one that outruns its budget and is killed
  along with what it started.
- The extractor protocol has contract fixtures, input and output documents in
  `contract/evidence/`, which the Ruby side parses and which a sample
  extractor, used in the process tests, answers from.
- `why`, `extract` and the digest are acceptance tests through the agent
  client, with evidence documents written through the recorder.
- One end-to-end test fails a real stage whose cause is only in a log file,
  and reads it back through `fun-ci why`.

## Order of work

The requirements are AT-10.1 to AT-10.17, in the order they are built: each
builds on what is already there, and masking is in place before fun-ci starts
keeping more than it keeps today. So `why` comes first, over the evidence §9
already keeps, then the digest's pointer to it, the output spool, masking,
configuration, the built-ins one family at a time, commands, `extract`,
overruns, the raw output, and `init`'s lists last.
