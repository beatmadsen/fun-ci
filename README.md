# Fun-CI

Opinionated local CI that checks your code before it leaves your machine. Runs a four-stage pipeline on every commit with strict time budgets, so your feedback loop stays fast.

## How It Works

Fun-CI hooks into git and runs your pipeline locally:

1. **Lint + Build** (parallel, 30s budget each) -- static analysis and compilation
2. **Slow suite** (spawned in background, 5min budget) -- integration/end-to-end tests
3. **Fast suite** (synchronous, 10s budget) -- unit tests

After each commit (**post-commit**), the entire pipeline forks to the background so your commit is not blocked. On **pre-push**, lint, build, and fast suite must pass before the push proceeds. The slow suite always runs in the background.

Results are stored in a local SQLite database. A terminal dashboard lets you monitor pipeline status across branches.

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
```

## Git Hooks

After `fun-ci install-hooks`, two hooks are active:

**post-commit** -- Runs `fun-ci trigger --background <commit> <branch>` for the commit you just made. This forks the pipeline into a background process and returns immediately, so commits are never blocked.

**pre-push** -- Runs `fun-ci trigger <commit> <branch>`. This validates the project config, runs lint + build + fast suite synchronously, and blocks the push if any stage fails. The slow suite runs in the background.

## Admin Dashboard

```bash
fun-ci console
```

Opens a terminal UI showing pipeline status across all branches. The header area displays animated ASCII art: a gentle starfield when idle, a rocket while pipelines run, and celebration/explosion animations on success or failure.

The console is drawn by a separate program, `fun-ci-renderer`. The gem for Linux (x86_64, aarch64, musl) and macOS (arm64, x86_64) includes it. On other systems you get the plain gem, where every command except `console` works; install the renderer with `cargo install fun-ci-renderer`, or point `FUN_CI_RENDERER` at a copy you built. When something goes wrong between the two, the details are in `.fun-ci/console.log`.

Navigation:

- `j` / `k` -- scroll up/down
- `c` -- cancel a running pipeline
- `q` -- quit

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
bundle exec rake   # the gate: tests, cucumber, rubocop
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT
