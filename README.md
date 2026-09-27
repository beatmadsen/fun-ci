# Fun-CI

Opinionated local CI that checks your code before it leaves your machine. Runs a four-stage pipeline on every commit with strict time budgets, so your feedback loop stays fast.

Fun-CI has two goals. It should be extremely easy to tell whether all is well: the console is meant to sit on a second screen, where colour and motion tell you at a glance what passed and what didn't, without reading a line. And it should be fun: a pass gets a celebration, a failure gets an explosion. The design behind both is in [docs/design.md](docs/design.md).

## How It Works

Fun-CI hooks into git and runs your pipeline locally:

1. **Lint + Build** (parallel, 30s budget each) -- static analysis and compilation
2. **Slow suite** (spawned in background, 5min budget) -- integration/end-to-end tests
3. **Fast suite** (synchronous, 10s budget) -- unit tests

After each commit (**post-commit**), the entire pipeline forks to the background so your commit is not blocked. On **pre-push**, lint, build and the fast suite of each commit you push must have passed before the push proceeds; a commit whose run has finished goes straight through. The slow suite always runs in the background.

Results are stored in a SQLite database in `~/.local/state/fun-ci/` (or `$XDG_STATE_HOME/fun-ci/`). A terminal dashboard lets you monitor pipeline status across branches, and a coding agent can ask for the same results from the command line.

Each pipeline runs in a git worktree of its own under `.git/fun-ci/worktrees/`, checked out at the commit it tests, so you can keep editing while it runs. Ignored files such as `vendor/bundle` or `node_modules` stay in a worktree from one run to the next, which keeps builds quick. Two pipelines run at once; set `worktree_slots: 3` in `.fun-ci/config` for more. `fun-ci prune` removes the worktrees when you want the space back.

## Getting Started

```bash
gem install fun_ci
cd your-project
fun-ci init --everything
```

This does three things:
1. Detects your project type and creates `.fun-ci/` with template scripts
2. Installs post-commit and pre-push git hooks
3. Verifies the setup is valid

`fun-ci init` has built-in templates for Ruby (Bundler), JVM (Gradle Kotlin, Gradle Groovy, Maven), but Fun-CI works with any project -- just write your own shell scripts.

### Manual Setup

If you prefer to set things up step by step:

```bash
fun-ci init              # Create .fun-ci/ with template scripts
fun-ci install-hooks     # Install git hooks
fun-ci check             # Verify everything is configured
```

Then edit the generated scripts in `.fun-ci/` to match your project:
- `lint.sh` -- linter/static analysis
- `build.sh` -- build/compile step
- `fast.sh` -- fast test suite (unit tests)
- `slow.sh` -- slow test suite (integration tests)

Each script receives the commit hash as its first argument.

## Commands

```
fun-ci trigger <commit> <branch>               Run the full pipeline
fun-ci trigger --background <commit> <branch>  Fork pipeline to background (used by post-commit)
fun-ci console                                 Launch the TUI dashboard
fun-ci init                                     Scaffold .fun-ci/ for detected project type
fun-ci init --everything                        init + install-hooks + check in one step
fun-ci install-hooks                            Install post-commit and pre-push hooks
fun-ci install-hooks post-commit                Install a single hook type
fun-ci check                                    Verify .fun-ci/ setup
fun-ci prune                                    Remove fun-ci's worktrees when no pipeline is running
fun-ci status [commit]                          Where a commit's run stands; the verdict is the exit code
fun-ci wait [commit]                            Wait until that verdict is decided, then exit with it
fun-ci runs                                     This project's recent runs, newest first
fun-ci events [--follow]                        The runs' events as JSON lines
fun-ci why [commit] [stage]                     Everything kept about why a stage failed
fun-ci extract <stage> --output <file>          Try a stage's extractors on a saved output
```

## For Coding Agents

An agent can't watch a dashboard, so it asks fun-ci about commits and acts on exit codes. After each commit, the commit's output ends with the command that gets its verdict:

```
fun-ci: testing 3f9c2ab. Verdict: fun-ci wait 3f9c2ab --need all
```

`fun-ci init` adds a short section to your `AGENTS.md` (or `CLAUDE.md`, if that is the only one) telling agents to run that command in the background after each commit. Agent harnesses that run a command in the background wake the agent when it exits, so it hears about a failure without having to remember to ask.

`status` and `wait` exit with the verdict for the stages you need: `--need build` (lint and build), `fast` (the default) or `all` (the slow suite too).

| Exit code | Meaning |
|---|---|
| 0 | Passed |
| 1 | A needed stage failed |
| 2 | A needed stage ran out of time |
| 3 | Still undecided (`wait --within 30s` gives up at your deadline) |
| 4 | Superseded by a newer commit on the branch (`wait --follow-branch` moves on to it) |
| 5 | No run for the commit |
| 64 | Usage error |

A failed stage comes with its evidence: the last lines it printed, or better, the failures its tests reported. fun-ci names an empty directory in `FUN_CI_REPORT` for every stage; write JUnit XML (`*.xml`) or `{"failures": [{"file", "line", "test", "message"}]}` (`*.json`) there. The Gradle and Maven scripts `fun-ci init` writes already copy their reports in. Every command takes `--json`.

## Git Hooks

After `fun-ci install-hooks`, two hooks are active:

**post-commit** -- Runs `fun-ci trigger --background <commit> <branch>` for the commit you just made. This forks the pipeline into a background process and returns immediately, so commits are never blocked.

**pre-push** -- Runs `fun-ci wait <commit> --need fast` for each commit the push sends. It waits for that commit's run (starting one if it has none) and blocks the push if lint, build or the fast suite failed, showing why. A project not set up for fun-ci pushes without CI.

## Admin Dashboard

```bash
fun-ci console
```

Opens a terminal UI showing pipeline status across all branches. Across the top runs an animated picture: a rocket while pipelines run, and a scene for each step a run passes. Lint passing gets a teal sweep, ripple or spirit level, the build amber blocks, gears or a ringing anvil, the fast suite a lightning strike, a very happy YAY or a jump to warp speed, and the whole run fireworks, a trophy, dancing leprechauns or a sunrise. A failure gets an explosion or shattering glass. Afterwards the header rests on the outcome, and when nothing has happened for five minutes it goes quiet: a starry night, an aurora, fireflies, a fire in a medieval stone hearth while a storm rages at the window, a moonlit island with a lone palm, or snow falling on a pine forest, with a small lamp in the corner, green if the last run passed and flickering red if it failed. It is drawn in 24-bit colour when `COLORTERM` says the terminal has it (`truecolor` or `24bit`), and in 256 colours otherwise.

The console is drawn by a separate program, `fun-ci-renderer`. The gem for Linux (x86_64, aarch64, musl) and macOS (arm64, x86_64) includes it. On other systems you get the plain gem, where every command except `console` works; install the renderer with `cargo install fun-ci-renderer`, or point `FUN_CI_RENDERER` at a copy you built. When something goes wrong between the two, the details are in `.fun-ci/console.log`.

Keys:

- `j` and `k`, or the arrow keys, move the cursor down and up
- `c` cancels the run under the cursor: a scheduled one at once, a running one once you answer `y` (`n` or `Esc` keeps it running)
- `q` quits

## Time Budgets

| Stage | Budget | Blocks |
|-------|--------|--------|
| Lint  | 30s    | push   |
| Build | 30s    | push   |
| Fast  | 10s    | push   |
| Slow  | 5min   | nothing (background) |

If a stage exceeds its budget, it is killed and reported as timed out.

## Development

```bash
bundle install
bundle exec rake   # the gate: tests, the renderer's tests, the binary contract, rubocop, clippy
```

How it is built is in [docs/architecture.md](docs/architecture.md), and the requirements still to build are in [docs/acceptance-tests.md](docs/acceptance-tests.md).

The renderer is written in Rust. Install Rust with [rustup](https://rustup.rs), which picks up the version the repository pins in `rust-toolchain.toml`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT
