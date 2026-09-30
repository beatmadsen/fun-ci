# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- The console's table has a look of its own. The header's night sky carries
  on below it; a row that needs you or is running has a stripe in the colour
  of why; each row's marks are joined into a track that fills from left to
  right (`✓─✓─◆┄·`); project names have a fading rule; passed branches folded
  into one line each have a `✓`; and the keys sit on caps. The block is a
  card with rounded corners, wine when its row needs you and indigo when the
  cursor only rests there.
- A run that ends washes its row in teal, coral or amber, draining from left
  to right, and a band of light travels along each running row.
- The failure and pass banners keep the sky behind them and take their
  colours from the table's.

## [2.1.0] - 2026-09-30

### Added
- Each run checks whether its commit would merge cleanly with the trunk:
  `trunk:` in `.fun-ci/config`, or else the remote's default branch.
  `status` and `wait` print where the commit stands, with its age; for a
  conflict, the files and when and how to integrate. A conflict is not a
  failure and changes no exit code, unless you ask with `--trunk`, which exits
  6 for a run that passed but conflicts and waits for the check.
  `fun-ci why REV trunk` prints each conflicted region. `status --json`,
  `runs` and `events` carry the check; `fun-ci check` names the trunk.
- fun-ci fetches the trunk itself, at most every five minutes, into
  `refs/fun-ci/trunk/`, touching none of your refs, and says so the first time.
  `trunk_fetch: false` stops it, and `trunk: none` turns the check off.
- The console says when a branch conflicts with the trunk, `conflicts with
  main` under it, and plays a knot tying, and later untying, in the header.
  This needs renderer 2.1.0, which the platform gems bring; with an older
  renderer, as `cargo install` left it, the console works but shows no
  conflicts.
- `fun-ci --help` lists `--raw`, which it left out.

### Changed
- The console's table is quieter. Each branch has one row, its newest run's,
  under its project's name, and reads as one phrase: the branch, a mark each
  for lint, build, fast and slow (`✓ ✓ ◆ ✓`), what happened in fun-ci's words
  (`failed in fast · 1.4s`, `running fast and slow · 7s`) and when. What needs
  you, a failure, a timeout or a conflict, comes first, and the first of it,
  or the row under the cursor, sits in one deep block that breathes; passed
  rows are pale, and fold into one line per project when nothing needs you.
  The colours come from the header's night scenes. On a wide terminal the
  table widens a little and sits in the middle; on a short one it folds and
  closes up before it leaves anything out, and says how many passed rows it
  left out. `c cancel` shows only when there is something to cancel.
- A stage's mark lights up and fades back when something happens to it. A
  pass glows gold and eases back to the mark's own colour, a timeout pulses
  amber twice, and a failure flares white on red and cools into the row. They
  last as long however often the console redraws; they used to run faster
  when boards arrived quickly.

### Fixed
- A console row wider than the terminal, from a long branch name or a
  failure word, wrapped onto the next line and pushed the board up, hiding
  the newest run under the header. Rows are now cut to fit, the branch first,
  and never wrap; the footer too.
- A branch named in Chinese, Japanese or Korean fills two columns a
  character, but the console counted one, so its marks slid out of line with
  the other rows' and a long name ran into them. Names are now measured, and
  cut, by the columns they fill.
- `.fun-ci/console.log`, where the console notes what went wrong between it
  and the renderer, was left for `git add` to sweep into a commit. The console
  now writes a `.fun-ci/.gitignore` naming it, unless the project has one there.

## [2.0.2] - 2026-09-29

### Fixed
- In a Gradle project set up by `fun-ci init`, the fast suite could fail
  before running a test, with Gradle unable to hash a file in its own build
  directory (`build/kotlin/compileTestKotlin/...`). The fast and slow suites
  run side by side in one worktree, and both compiled the test code into the
  same place, each deleting what the other was reading. The build script now
  compiles the test code (`./gradlew assemble testClasses`), so neither suite
  has to. Maven, .NET, Elixir, Dart and Swift projects could clash the same
  way, and their scripts change too: Maven builds with `mvn test-compile` and
  runs `mvn surefire:test` and `mvn failsafe:integration-test
  failsafe:verify`, so its slow suite now runs only the integration tests
  failsafe finds (the classes named `*IT`) rather than every test again;
  Elixir compiles its test environment in the build; Dart precompiles its test
  runner and runs the slow suite from source; the .NET and Swift suites run
  with `--no-build` and `--skip-build`.
- Lint runs side by side with the build, and the lint `fun-ci init` wrote for
  Maven (`mvn verify -DskipTests`) and .NET (`dotnet format`) compiled into
  the same directories as the build. Lint now works on the source code alone.
  Maven's runs the linter the POM configures (detekt, ktlint, checkstyle or
  PMD) or else `mvn validate`, and no longer picks spotbugs, which reads
  compiled classes. .NET's checks whitespace with `dotnet format whitespace
  --folder`. Gradle's runs ktlint, spotless or detekt when the build applies
  one, and otherwise says there is none, where it ran `check`, which compiles.
  A linter that needs compiled code goes in `build.sh` or `fast.sh`.
- Which stages run side by side, and so what each may read and write, is now
  spelled out: in a new section of `docs/design.md`, in the README, in what
  `fun-ci init` prints, and in a comment at the top of each script it writes.
  Scripts already in `.fun-ci/` are left as they are, so an existing project
  picks up these fixes by editing them to match `docs/stacks.md`.

## [2.0.1] - 2026-09-29

### Fixed
- `fun-ci console` could show a blank screen and stay that way. When a new
  commit cancelled a run in the same second one of its stages started, the
  stage was recorded as ending before it began. The renderer rejected the
  negative duration and, with it, every board Ruby sent, so nothing was drawn
  while that run was listed; the only sign was a line per second in
  `.fun-ci/console.log`. Ends are now recorded to the millisecond, and a stage
  already recorded that way reads as taking no time, so an existing database
  needs no repair. `fun-ci status`, `why` and `events` no longer report a
  negative time for such a stage either.
- A commit made on a detached HEAD, as every commit a rebase replays is, was
  recorded with no branch name, so `fun-ci status` ended in "on" and the
  console showed a gap where the branch goes. Such runs are now on the branch
  `detached`, whether a hook or `fun-ci wait` started them, and runs already
  recorded without a name are renamed when fun-ci next opens its database.

## [2.0.0] - 2026-09-29

fun-ci 2.0 has two ways in. People watch a new console, drawn by a Rust
renderer in 24-bit colour, with a scene for each milestone a run passes. Coding
agents and scripts ask with new commands (`status`, `wait`, `why`, `runs`,
`events`) that answer with exit codes and keep enough of each failure to say
why it failed without running the suite again. Pipelines now run in git
worktrees at the commit they test, started after the commit rather than
before it. See "Upgrading to 2.0" in the README.

### Changed
- The hook that runs a pipeline in the background is now `post-commit`, so it
  tests the commit you just made; the `pre-commit` hook tested the commit
  before it. `fun-ci install-hooks` writes `post-commit` and `pre-push`, and
  removes the `pre-commit` hook fun-ci 1.x wrote. A `pre-commit` hook of your
  own is left alone, and if it still calls fun-ci, `fun-ci check` warns you
  to take that out. Run `fun-ci install-hooks` again to update your hooks;
  until you do, `fun-ci check` warns that each run tests the commit before
  yours.
- The pre-push hook waits for the fast verdict of each commit the push sends
  (`fun-ci wait SHA --need fast`) instead of running the pipeline again, so a
  push after a finished post-commit run goes through at once. It reads the
  commits from what git passes it, so pushing a branch other than the one
  checked out tests the right commits.
- Every pipeline runs in a git worktree of its own, checked out at the commit
  it tests, under `.git/fun-ci/worktrees/`. Before, the stages ran in your
  checkout while you kept editing it. Ignored files such as `vendor/bundle`
  stay in a worktree from one run to the next. The stage scripts come from
  the commit too, unless it has no `.fun-ci/`, in which case the checkout's
  are used. Two pipelines run at once by default; set `worktree_slots: 3` (or
  any number above 0) in `.fun-ci/config` for more.
- fun-ci keeps its database in `$XDG_STATE_HOME/fun-ci/`, or
  `~/.local/state/fun-ci/` without it, instead of under `$TMPDIR`, so every
  process of a user finds the same database, including an agent in a sandbox
  with a `TMPDIR` of its own. Runs recorded by 1.x are not carried over. The
  state directory is readable by its user alone (0700).
- A newer commit cancels an older unfinished run on its branch only in its own
  project, never a run an agent is waiting on, and never a run of the same
  commit.
- `fun-ci console` is drawn by a separate program, `fun-ci-renderer`, written
  in Rust. The gems for Linux (x86_64, aarch64, musl) and macOS (arm64,
  x86_64) include it. Elsewhere, install it with `cargo install
  fun-ci-renderer` or point `FUN_CI_RENDERER` at a copy you built; without
  it, `console` says so and every other command works as before. What goes
  wrong between the two ends up in `.fun-ci/console.log`, since the renderer
  owns the terminal.
- The console's header is a picture rather than ASCII art: soft light,
  gradients and particles in 24-bit colour across the whole width, or the
  nearest of 256 colours when `COLORTERM` doesn't say `truecolor` or `24bit`.
  Only the parts that change are sent to the terminal.
- The header plays a scene for each milestone a run passes, each milestone
  with scenes of its own, so you can tell which it was without reading: a teal
  sweep, ripple or spirit level for lint; amber blocks, gears or a ringing
  anvil for the build; a lightning strike, YAY or a jump to warp speed for the
  fast suite; fireworks, a trophy, dancing leprechauns or a sunrise for the
  whole run; an explosion or shattering glass for a failure. Scenes queue and
  each plays to its end, so a failure no longer cuts a celebration short, and
  a run gets one failure scene however many of its stages fail.
- When the scenes are done, the header rests on how the latest run went: a
  calm dusk with a tick after a pass, a pulsing hazard sign after a failure.
  Five minutes after the latest run finished it goes quiet: a starry night,
  an aurora, fireflies, a fire in a medieval stone hearth with a storm at the
  window, a moonlit island with a palm, or snowfall over pines, a different
  one every five minutes while nothing runs, with a small lamp in the corner
  that stays green after a pass and flickers red after a failure. The streak
  ("7 in a row!", or "streak broken") sits in the top right.
- The console's board fits the terminal's height and scrolls to keep the
  cursor on screen.
- The console's cancel prompt names the run it would cancel, as in
  `Cancel feat/search (d4e5f67)? y / n`.
- With no runs yet, the console suggests `fun-ci init --everything`. It used to
  suggest `fun-ci trigger HEAD`, which fails without a branch, and
  `fun-ci install-hook pre-push`, which does not exist.
- When a stage fails, `fun-ci trigger` says what to do next, such as "Fix the
  failing tests above, then try again."
- A project's colour in the console stays the same from one start to the next.

### Added
- `fun-ci status [REV]` says where a commit's run stands, stage by stage, and
  exits with a verdict an agent can branch on: 0 passed, 1 failed, 2 over
  budget, 3 undecided, 4 superseded, 5 no run, 64 usage error. `--need
  build|fast|all` says which stages must pass (fast by default), and `--json`
  prints one JSON document.
- `fun-ci wait [REV]` waits for that verdict and exits with it: as soon as the
  stages `--need` names have passed, or at the first of them to fail or
  overrun. `--within 30s` gives up undecided (exit 3). A commit with no run
  after 5 seconds gets one started. `wait` on a superseded run exits 4 naming
  the newer commit, and `--follow-branch` moves on to that commit's run.
- `fun-ci runs` lists the project's recent runs, one line each; `-n N`,
  `--branch NAME` and `--json`.
- `fun-ci events` prints the project's runs' events as JSON lines (run
  started, stage finished, run finished, run superseded); `--follow` keeps
  printing them as they happen, and `--only failures` keeps to failed or
  over-budget stages and superseded runs.
- After each commit, the hook's output ends with the `fun-ci wait` command
  that gets its verdict, and `fun-ci init` adds a short section to the
  project's `AGENTS.md` (or `CLAUDE.md` when that is the only one) telling
  agents to run it in the background.
- `fun-ci why [REV] [STAGE]` prints everything fun-ci kept about a failed
  stage: how it exited, how long it took against its budget, each reported
  failure with its whole message and its own output, what the extractors
  picked out, and the last lines of its output. `status` and `wait` end with
  a digest of it and the `why` command. `why --raw` prints the stage's whole
  output, kept for a project's 10 newest runs as its first 1 MB and last
  7 MB, compressed. The end of a failed stage's output (200 lines, at most
  64 KB) is kept for the 50 newest.
- A `junit-files` entry under `evidence:` keeps each failure in the JUnit XML
  a stage wrote (`build/test-results/**/*.xml`, `target/surefire-reports/*.xml`),
  with the output each failure printed, and leaves alone reports an earlier
  run left behind. `status --json` gives them to a program. fun-ci now depends
  on `rexml` to read them.
- Every stage script finds its stage's name in `FUN_CI_STAGE`.
- Secrets are masked before fun-ci keeps anything a stage printed: the value
  of any variable in the stage's environment whose name holds TOKEN, SECRET,
  PASSWORD, PASSWD, API_KEY, PRIVATE_KEY or CREDENTIAL (8 characters or more)
  shows as `[masked:NAME]`, and GitHub, AWS and Slack tokens, private keys and
  `Authorization:` headers as `[masked]`. `mask:` under `evidence:` adds
  patterns.
- Presets pick out a tool's failures from a stage's output, for 34 tools,
  each checked against the recorded output of a real failing run: rspec,
  Minitest, Gradle, Maven, pytest, unittest, Jest, Vitest, Mocha, Node's test
  runner, Bun, Deno, go test, cargo test, dotnet test, PHPUnit, ExUnit, swift
  test, dart test, GoogleTest, tsc, ESLint, RuboCop, Ruff, mypy, go build,
  rustc, gcc, ShellCheck, Perl's prove, and JSON logs from
  logstash-logback-encoder, Elastic's ECS encoders, pino and structlog. With
  no configuration fun-ci runs those whose marker files the project has
  (`Gemfile`, `pom.xml`, ...) and whose tool's output the failure shows;
  `fun-ci why` says why each was chosen and `fun-ci check` lists them.
- `fun-ci init` writes stage scripts for every stack a preset reads, not only
  Ruby and the JVM: rspec projects, Rust, Go, Elixir, Dart, Swift, PHP, .NET,
  Python (uv, Poetry, pip), Deno, Bun, Node (pnpm, Yarn, npm), Perl, CMake and
  make.
- A project says what else to keep when a stage fails under `evidence:` in
  `.fun-ci/config`, within a budget of 2 seconds: `grep`, `section` (with a
  `preset:`), `log-file` (what the stage wrote to a log file, and only that),
  `json-log` (records at or above a level, with the fields of a named preset or
  your own), `junit-files` (JUnit XML a build tool writes in its own place),
  and `run:`, your own extractor in any language, which gets the context as
  JSON on stdin and prints text or JSON. `detect: false` and `skip: [name]`
  turn presets off. The documents a `run:` extractor reads and prints are
  pinned in `contract/evidence/`.
- A stage that runs over budget says what it was doing: before the kill,
  fun-ci lists its processes and the deepest one still running, and `status`
  and `wait` lead with it (`fast ran over budget: running java ...
  GradleWorkerMain (9.8s)`). A `run:` entry with `on: overrun` runs then, with
  the stage's process group in `FUN_CI_PGID`, for a thread dump.
- When another stage shared the worktree while a stage ran (lint beside
  build, the slow suite beside the fast one), `fun-ci why` says so
  (`alongside: slow`), since a log file may hold both stages' lines.
- `fun-ci extract STAGE --output FILE` runs a stage's extractors against a
  saved output and prints what `why` would, so an extractor can be tried
  without making a commit.
- `fun-ci check` reports a mistake under `evidence:` or a `run:` script that
  is missing or can't be run. A mistake never stops a pipeline: the entry is
  left out and `fun-ci why` names it as a problem.
- `fun-ci prune` deletes the worktrees fun-ci keeps and has git forget them.
  It refuses, and deletes nothing, while a pipeline is running.
- `.fun-ci/console.log` notes when the console starts and stops and why it
  stopped, what it sent every ten minutes, and when the renderer stops
  reading or a frame takes a second or more to reach the terminal.
- `fun-ci-renderer --colours 24bit|256` chooses the colours to draw in.

### Deprecated
- `fun-ci trigger --no-validate` is the old name for `--background`. It works
  until 2.1 and says so on stderr.

### Removed
- The `fun-ci-trigger` and `fun-ci-tui` executables. Use `fun-ci trigger` and
  `fun-ci console`, which have done the same job since 1.0.

### Fixed
- In a pipeline started in the background, as the post-commit hook starts
  them (and 1.x's pre-commit hook did), the fast suite waited for the slow
  suite to finish before it began. It now runs beside it, so the verdict a
  push waits for comes when the fast suite is done, not the slow one.
- A commit on a branch cancelled every unfinished run on a branch of that
  name in every project, because all projects share one database. It now
  cancels only its own project's runs.
- Cancelling a stale pipeline left its stage scripts running and could let
  the old run record itself as failed after it was cancelled. fun-ci now
  records every process a run starts and stops all of them, and cancels runs
  still waiting for a worktree as well. A run that had already died is only
  marked cancelled, since the process ids it left behind may belong to
  something else by now.
- Cancelling a run from the console (`c`, then `y`) only marked it
  cancelled; its stages kept running. It now stops the run.
- A run whose fast suite failed could end up PASSED when its slow suite passed
  afterwards, and a run showed PASSED for a moment when the slow suite
  finished before the fast suite. A run's status now follows from all four
  stages, whichever finishes first.
- A slow suite whose process died without finishing left its run RUNNING for
  ever. The console now records it failed on its next poll.
- A database that stays busy, or can't be written because the disk is full,
  no longer stops `fun-ci trigger`: the stages still run, the exit code is
  theirs, and fun-ci says once that the run wasn't recorded.
- Two fun-ci processes starting at once against a database that didn't exist
  yet (the first commit and push on a machine, say) could die with `database
  is locked` or `duplicate column name: project_path`. They now take turns.
- The git hooks blocked a push when fun-ci wasn't installed, failing with
  "fun-ci: command not found". Now they say fun-ci is missing, how to install
  it, and let the push go ahead.
- Git runs hooks with variables such as `GIT_INDEX_FILE` pointing at the
  checkout. fun-ci passed them on to the git commands it runs and to your
  stage scripts, which then read the checkout's index instead of the
  commit's. They are cleared now.
- `fun-ci install-hooks` wrote into `.git/hooks` even when `core.hooksPath`
  sends git elsewhere (as husky sets it), so git never ran the hooks; and in
  a linked worktree, whose `.git` is a file, it said the project wasn't a git
  repository. It now asks git where the hooks go.
- Every stage failed in a project whose path held a space, with "cannot
  execute: No such file or directory". The stage script's path is quoted now.
- A stage that printed without end grew fun-ci's memory without end, since
  its output was held in memory. It is written to disk as it runs now.
- The phase 1 line printed lint and build in whichever order they finished.
  Lint always comes first now.

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
