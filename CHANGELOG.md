# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `fun-ci why [commit] [stage]` prints everything fun-ci kept about a failed
  stage: how it exited, how long it took against its budget, each reported
  failure with its whole message, and the last lines of its output. Without a
  stage it explains the one that decided the verdict, and it exits with the
  verdict, as `status` does.
- Secrets are masked before fun-ci keeps anything a failed stage printed:
  the value of any variable in the stage's environment whose name holds
  TOKEN, SECRET, PASSWORD, PASSWD, API_KEY, PRIVATE_KEY or CREDENTIAL (8
  characters or more) shows as `[masked:NAME]`, and GitHub, AWS and Slack
  tokens, private keys and `Authorization:` headers as `[masked]`. The state
  directory is now readable by its user alone (0700), since masking is a best
  effort.
- A failed stage's whole output is kept for a project's 10 newest runs, as
  its first 1 MB and last 7 MB with a line saying how much was dropped
  between them, masked and compressed, and `fun-ci why --raw` prints it. A
  stage's output is written to disk as it runs, in the state directory,
  instead of being held in memory, so a stage that prints without end no
  longer grows fun-ci's memory without end.
- Every stage script finds its stage's name in `FUN_CI_STAGE`, so a project
  can send each stage's logs to a file of its own.
- A project can say what else to keep when a stage fails, under `evidence:`
  in `.fun-ci/config`: for example a `grep` for `ERROR` lines, with lines of
  context, in the output or in a log file. Each stage's entries run when it
  fails, the slow suite's too, within a budget of 2 seconds (`budget:`), and
  `mask:` adds patterns to mask.
- `fun-ci check` reports a mistake under `evidence:` (an unknown extractor,
  an option it doesn't take, a pattern that doesn't compile). A mistake never
  stops a pipeline: the entry is left out and `fun-ci why` names it as a
  problem.
- Presets pick out a tool's failures from a stage's output: `use: section`
  with `preset: rspec`, `minitest`, `gradle` or `maven`. Each is checked
  against the recorded output of a real failing run of its tool.
- `use: log-file` keeps what a stage wrote to the log files under a glob
  (`path: log/test.log`), and only that: a worktree slot's log still holding
  a previous run's lines is read from where it stood when the stage started,
  or from its start when it was rotated. `grep:`, `start:` and `lines:`
  narrow it down.
- When another stage of the run shared the worktree while a stage ran (lint
  beside build, the slow suite beside the fast one), `fun-ci why` says so
  (`alongside: slow`), since a log file may hold both stages' lines.
- `use: json-log` keeps the JSON log records at or above a level (`level:
  warn` by default) as one line each (time, level, logger, message) followed
  by the stack trace, out of thousands of lines at `debug`. Presets name the
  fields of logstash-logback-encoder (`preset: logstash`) and Elastic's ECS
  encoders (`preset: ecs`); `fields:` names a setup's own.
- A failure keeps its own output: a JUnit test case's `<system-out>` and
  `<system-err>`, or `output` in fun-ci's JSON report, is kept (its last 4
  KB) and `fun-ci why` prints it under the failure's message.
- `use: junit-files` reads the JUnit XML a build tool writes in its own
  place (`paths: [build/test-results/**/*.xml]`) during the stage; a failure
  that also arrives through `FUN_CI_REPORT` is kept once.
- A project can write its own extractor in any language: `run: <command>`
  in a stage's list runs it in the worktree when the stage fails, with the
  context (the stage, how it ended, the commit, where its output and reports
  are, the watched files it wrote) as JSON on stdin. It prints text, kept as
  an excerpt, or with `format: json` facts, failures and excerpts. A command
  that outruns the evidence budget is killed with everything it started, and
  a bad exit, bad JSON or more than 256 KB of output is recorded as a
  problem. `fun-ci check` reports a `run:` script that is missing or can't be
  run. The documents are pinned in `contract/evidence/`.
- `fun-ci extract STAGE --output FILE` runs a stage's extractors against a
  saved output (`fun-ci why --raw > FILE` saves one), with the current
  directory as the worktree, and prints what `why` would print, so an
  extractor can be written and tried without making a commit. It touches no
  database.
- A stage that runs over budget says what it was doing: before the kill,
  fun-ci lists its processes and the deepest one still running, and
  `status` and `wait` lead with it (`fast ran over budget: running java ...
  GradleWorkerMain (9.8s)`). A `run:` entry with `on: overrun` runs then
  too, with the stage's process group in `FUN_CI_PGID`, for `jcmd`,
  `py-spy dump` or a JVM thread dump; what it makes the stage print is kept.
  This adds at most 2 seconds to a stage that has already blown its budget.
- When all fun-ci kept of a failed stage is its output's last lines, `fun-ci
  why` ends by saying so, and that extractors under `evidence:` in
  `.fun-ci/config` keep more.
- With no configuration, fun-ci picks the presets that apply: those whose
  marker files the project has (`Gemfile`, `pom.xml`, `build.gradle`, ...)
  and whose tool's output the failure shows, so presets for other stacks cost
  a project nothing. `fun-ci why` says why each was chosen, `fun-ci check`
  lists the presets the project's files select, and `evidence:` takes
  `detect: false` and `skip: [name]`.
- Presets for 34 tools, each checked against the recorded output of a real
  failing run: test runners rspec, Minitest, Gradle, Maven, pytest,
  unittest, Jest, Vitest, Mocha, Node's test runner, Bun, Deno, go test,
  cargo test, dotnet test, PHPUnit, ExUnit, swift test, dart test and
  GoogleTest; tsc, ESLint, RuboCop, Ruff, mypy, go build, rustc, gcc and
  ShellCheck; Perl's prove; and JSON logs from logstash-logback-encoder,
  Elastic's ECS encoders, pino and structlog.

### Changed
- The pre-push hook waits for the fast verdict of each commit the push
  sends (`fun-ci wait SHA --need fast`) instead of running the pipeline
  again, so a push after a finished post-commit run goes through at once.
  The post-commit hook's output now ends with the `fun-ci wait` command that
  gets the commit's verdict. Run `fun-ci install-hooks` again to update
  hooks you already have.
- fun-ci keeps its database in `$XDG_STATE_HOME/fun-ci/`, or
  `~/.local/state/fun-ci/` without it, instead of under `$TMPDIR`. Every
  process of a user now finds the same database, including an agent in a
  sandbox with a `TMPDIR` of its own. Runs recorded under `$TMPDIR` before
  are not carried over.
- The console's header plays a scene each time a run passes a milestone:
  lint, build, the fast suite, and the whole run. The scenes queue and each
  plays to its end, so a failure no longer cuts a celebration short, and a run
  gets one explosion however many of its stages fail. Each milestone has
  scenes of its own, so you can tell which one it was without reading: a teal
  sweep or ripple for lint, amber blocks or gears for the build (both new),
  the lightning strike or YAY for the fast suite, and fireworks, the trophy
  or the leprechauns when the whole run passes.
- When the scenes are done and nothing is running, the header rests on how
  the latest run went: a calm dusk with a tick after a pass, and a pulsing
  hazard sign after a failure, so a glance a minute later still tells you.
- Each kind of scene has a new one to pick from: a spirit level settling
  true when lint passes, a hammer ringing on an anvil when the build does, a
  jump to warp speed for the fast suite, a sunrise for a passing run, and
  shattering glass for a failure.
- The starry night is back, meaning "nothing has happened for a while": five
  minutes after the latest run finished, the header leaves the pass or
  failure screen for a quiet scene, the starry night or one of two new ones
  (an aurora, fireflies, a fire in a medieval stone hearth with lightning and rain at the window, a moonlit castaway's island with a palm, snowfall over pines), with a small lamp in the corner that stays green
  after a pass and flickers red after a failure.
- The streak is back: the header's top right says how many runs in a row
  have passed ("7 in a row!"), or "streak broken" after a failure. It went
  missing when the header became a picture.
- The console's animations are redrawn as pictures rather than ASCII art:
  soft light, gradients and particles in 24-bit colour, filling the whole
  width of the header. The idle sky, the rocket, the explosion and the five
  celebrations keep their themes. Terminals without `COLORTERM=truecolor`
  get the nearest of 256 colours. Only the parts of the picture that change
  are sent to the terminal.
- An idle console now redraws four times a second, so the night sky moves
  smoothly; it used to redraw once a second.

### Removed
- `fun-ci-renderer --animations <dir>`, which loaded animation frames from
  JSON files. The animations are code in the renderer now.

### Added
- `fun-ci events` prints this project's recent runs' events as JSON lines
  (`schema`, `event`, `commit`, `branch`, and `stage`, `state`, `seconds`
  for a stage): run started, stage finished, run finished, run superseded.
  `--follow` keeps printing each new one as it happens, for a supervising
  agent or a status bar, and `--only failures` keeps to failed or
  over-budget stages and superseded runs.
- `fun-ci init` adds a short fun-ci section to the project's `AGENTS.md`,
  or to `CLAUDE.md` when that is the only one, creating `AGENTS.md` when
  there is neither: after each commit, run the `fun-ci wait` command the
  commit prints, in the background. It adds it once, and also to a
  project that already has `.fun-ci/`.
- `fun-ci wait [REV]` waits for a commit's verdict and exits with it, as
  `status` would say it: it returns as soon as the stages `--need` names
  have passed, or at the first of them to fail or overrun. `--within 30s`
  gives up undecided (exit 3) at the agent's deadline. A commit with no run
  after 5 seconds gets one started, as the post-commit hook would. A run an
  agent is waiting on is no longer cancelled by a newer commit on its
  branch, and a run is never cancelled by another of the same commit;
  `wait` on a superseded run exits 4 naming the newer commit, and
  `--follow-branch` moves on to that commit's run.
- Each stage gets an empty directory named by `FUN_CI_REPORT`. A stage that
  writes JUnit XML (`*.xml`) or fun-ci's JSON (`*.json`,
  `{"failures": [{"file", "line", "test", "message"}]}`) there has its
  failures kept when it fails, and `fun-ci status` lists them (file, line,
  test and the first lines of the message) instead of the output's last
  lines; `status --json` gives them under each stage. The Gradle and Maven
  scripts `fun-ci init` writes copy the build's reports there. fun-ci now
  depends on `rexml` to read them.
- A stage that fails or runs out of time keeps the end of its output: the
  last 200 lines, at most 64 KB, colour codes stripped. The slow suite's
  output is kept too, and a stage killed over budget keeps what it printed
  before the kill. `fun-ci status` shows the last 20 lines of each needed
  stage that failed. Only a project's 50 newest runs keep their output.
- `fun-ci runs` lists this project's recent runs, newest first, one line
  each: short SHA, branch, age, each stage's outcome and the subject. `-n N`
  sets how many (10 by default), `--branch NAME` keeps to one branch, and
  `--json` prints each as the document `status --json` gives.
- `fun-ci status [REV]` says where a commit's run stands in this project,
  stage by stage, and exits with the verdict an agent can branch on: 0
  passed, 1 failed, 2 over budget, 3 undecided, 4 superseded, 5 no run, 64
  usage error. `--need build|fast|all` says which stages must pass (fast by
  default), and `--json` prints one JSON document instead of text.
- `fun-ci-renderer --colours 24bit|256` chooses the colours to draw in.
- When a stage fails, `fun-ci trigger` says what to do next, such as "Fix the
  failing tests above, then try again."

### Fixed
- Cancelling a run, from the console or by a newer commit, could leave the
  slow suite's script running: the suite could start it after the canceller
  had looked at the run and before it stopped the suite. The canceller now
  looks again once the run's own processes are gone, and stops any stage
  started in between.
- A commit on a branch cancelled every unfinished run on a branch of that
  name, in every project, because all projects share one database. A commit
  on `main` in one project stopped another project's pipeline on `main`. It
  now cancels only its own project's runs.
- A slow suite whose process dies without finishing no longer leaves its run
  RUNNING for ever: the console records it failed on its next poll.
- A database that stays busy, or can't be written because the disk is full,
  no longer stops `fun-ci trigger`: the stages still run, the exit code is
  theirs, and fun-ci says once that the run wasn't recorded (naming the
  database when it can't write to it).
- A run whose fast suite failed no longer ends up PASSED when its slow suite
  passes afterwards, and a run no longer shows PASSED for a moment when the
  slow suite finishes before the fast suite. A run's status now follows from
  all four stages, whichever finishes first.
- The git hooks no longer block a push when fun-ci isn't installed. The
  pre-push hook failed with "fun-ci: command not found" and stopped the push;
  now it says fun-ci is missing, how to install it, and lets the push go
  ahead. Run `fun-ci install-hooks` again to update hooks you already have.
- A `.fun-ci/config` that isn't valid YAML made `fun-ci check` and
  `fun-ci trigger`, and so every commit's hook, fail with a stack trace.
  Both now name the mistake and the line it is on, and `trigger` runs no
  pipeline until it is fixed, as for any other mistake in `.fun-ci/`.
- Every stage failed in a project whose path held a space, with "cannot
  execute: No such file or directory": the stage script's path was split
  at the space. It is quoted now.

## [2.0.0] - 2026-09-25

### Added
- `fun-ci prune` deletes the worktrees fun-ci keeps under
  `.git/fun-ci/worktrees/` and has git forget them. It refuses, and
  deletes nothing, while a pipeline is running.

### Changed
- The hook that runs a pipeline in the background is now `post-commit`,
  so it tests the commit you just made; the `pre-commit` hook tested the
  commit before it. `fun-ci install-hooks` writes `post-commit` and
  `pre-push`. `fun-ci trigger --background` is the new name for
  `--no-validate`, which still works until 2.1 and says so on stderr.
  `install-hooks` removes the `pre-commit` hook fun-ci 1.x wrote. A
  `pre-commit` hook of your own is left alone, and if it still calls
  fun-ci, `fun-ci check` warns you to take that out.
- Every pipeline now runs in a git worktree of its own, checked out at the
  commit it is testing, under `.git/fun-ci/worktrees/`. Before, the stages ran
  in your checkout while you kept editing it. The stage scripts come from the
  commit too, unless it has no `.fun-ci/`, in which case the checkout's are
  used. Two pipelines run at once by default; set `worktree_slots: 3` (or
  any number above 0) in `.fun-ci/config` for more.
- `fun-ci console` is drawn by a separate program, `fun-ci-renderer`,
  written in Rust. The gems for Linux (x86_64, aarch64, musl) and macOS
  (arm64, x86_64) include it. Elsewhere, install it with
  `cargo install fun-ci-renderer` or point `FUN_CI_RENDERER` at a copy you
  built; without it, `console` says so and every other command works as
  before. What the renderer reports going wrong ends up in
  `.fun-ci/console.log`, since it owns the terminal.
- The console's cancel prompt names the run it would cancel, as in
  `Cancel feat/search (d4e5f67)? y / n`, instead of the generic
  "Cancel running pipeline? y/n".

### Removed
- The `fun-ci-trigger` and `fun-ci-tui` executables. Use `fun-ci trigger` and
  `fun-ci console`, which have done the same job since 1.0.

### Bug Fixes
- With no runs yet, the console suggested `fun-ci trigger HEAD`, which fails
  without a branch, and `fun-ci install-hook pre-push`, a command that does
  not exist. It now suggests `fun-ci init --everything` and says each commit
  then starts a run.
- Git runs hooks with variables such as `GIT_INDEX_FILE` pointing at the
  checkout. fun-ci passed them on to the git commands it runs and to your
  stage scripts, which then read the checkout's index instead of the
  commit's. They are cleared now.
- Cancelling a stale pipeline (a newer commit on the same branch) left its
  stage scripts running and could let the old run record itself as failed
  after it was cancelled. fun-ci now records every process a run starts and
  stops all of them, its own first, and cancels runs still waiting for a
  worktree as well. A run that had already died is only marked cancelled:
  the process ids it left behind may belong to something else by now.
- Cancelling a run from the console (`c`, then `y`) only marked it
  cancelled; its stages kept running. It now stops the run the same way,
  whether the fast suite is still running or only the slow suite is left.
- Two fun-ci processes starting at the same moment against a database that
  didn't exist yet (the first commit and push on a machine, say) could die
  with `database is locked` or `duplicate column name: project_path`.
  Setting up the database now takes a lock file beside it, so they take
  turns.
- The phase 1 line printed lint and build in whichever order they finished,
  so the same result could read `build ok  lint ok`. Lint always comes first
  now.
- A project's name in the console changed colour every time the console
  started, because the colour came from `String#hash`, which Ruby seeds per
  process. It now comes from a CRC-32 of the name and stays the same.

## [1.2.1] - 2026-09-20

### Bug Fixes
- `StageRunner` raised `NameError: uninitialized constant FunCi::NullRecorder`
  when built without an explicit recorder. The module reorganisation in 1.2.0
  moved `NullRecorder` under `Persistence` and the default argument was left
  pointing at the old name. The file also never required the recorder it names,
  so the constant was only ever resolvable by luck of load order.

### Changed
- The gemspec reads the version from a new `lib/fun_ci/version.rb` instead of
  loading the whole library. Loading the library pulls in sqlite3, and Bundler
  reads the gemspec before it installs anything, so `bundle install` failed on
  any machine that did not already happen to have sqlite3.
- `required_ruby_version` is now `>= 3.2`. The stated floor of 3.0 was never
  reachable: the TUI uses `Data.define`, which arrived in Ruby 3.2.

### Internal
- The cucumber suite had been broken since the 1.2.0 reorganisation, which moved
  the files and constants it loads. It runs again, `rake` runs it, and it runs
  with `--strict` so an undefined step fails instead of passing quietly.
- `StageRunner` has tests. It had none, which is how the broken default survived.

## [1.2.0] - 2026-02-23

### Bug Fixes
- Replaced unreliable `Timeout.timeout` with process groups (`pgroup: true`) and `Thread#join` for reliable time budget enforcement on lint/build/fast/slow stages
- Fixed off-by-one in TUI row truncation that caused the top pipeline row to be hidden behind the header in short terminals
- Added `Screen#height=` to clear screen on terminal height changes, preventing the header from scrolling off-screen when tmux panes resize
- Fixed header flicker by skipping `println` when animation is active
- Allowed null SHA on root commits so pipeline still runs
- Detected multi-module Gradle projects from `settings.gradle`

### Refactoring
- Extracted `TerminalInput`, `KeyHandler`, `BoardRenderer` from `AdminTui` (was 257 lines/12 ivars, now 4 focused classes all under 150 lines/4 ivars)
- Organized flat `lib/fun_ci/` into cohesive module subdirectories: `persistence/`, `pipeline/`, `setup/`, `tui/`

### Internal
- Extracted shared `ProcessRunner` module for consistent process spawning across stages
- Updated `BackgroundWrapper` to use `[output, status, timed_out]` triples instead of exception-based timeout signaling
- Truncated TUI board rows to fit terminal height

## [1.1.0] - 2026-02-22

### Added
- Multi-line ASCII art header animations for pipeline events (explosion on failure, celebrations on success)
- Looping idle starfield animation in the TUI header
- Rocket animation while pipelines are running, with flickering exhaust and parallax starfield
- HeaderAnimationManager with idle/running/event state transitions
- AnimationLibrary with 8 animation data files (explosion, success, celebrate, flash, leprechauns, yay, idle, running)

### Fixed
- Footer animations now display 8x slower so text is actually readable
- Animation refresh no longer blocks for 5 seconds between frames when no pipelines are running
- Removed stale single-line header banner that conflicted with multi-line animations
- Animation frames padded to global max width across all frames, preventing horizontal jitter

## [1.0.0] - 2026-02-21

### Added
- Four-stage local CI pipeline (lint, build, fast, slow) with strict time budgets (30s/30s/10s/5min)
- Unified CLI (`fun-ci`) with subcommands: trigger, console, init, install-hooks, check
- Pre-commit hook (background fork, non-blocking) and pre-push hook (synchronous, blocking)
- TUI dashboard with vim-style navigation (j/k/c/q), pagination, and project path display
- Project scaffolding with built-in templates for Ruby (Bundler), JVM (Gradle Kotlin/Groovy, Maven)
- SQLite persistence with WAL mode for pipeline results
- Parallel lint + build stages with background slow suite
- Smart Maven linter detection for template generation
- Stale pipeline auto-cancellation
