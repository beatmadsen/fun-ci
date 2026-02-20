# fun-ci Roadmap

Does not include completed work.

## Smart installer

A command that sets up fun-ci for a project, including creating the `.fun-ci/` folder and populating it with template scripts suitable for the project's language and build system.

We can't have templates for everything, but we can build an extensible system that I can build up over time, starting with the languages and build systems I'm most familiar with.

Things I know I will need at this pont:
- ruby bundle, have a look at my projects in ~/Developer/hobby/ruby and ~/Developer/hobby/rails for examples
- jvm gradle: kotlin and groovy flavours
- jvm maven, typically using surefire for unit/fast tests and failsafe for integration/slow tests

### `fun-ci init`

Creates `.fun-ci/`, generates real working template scripts (not stubs) with comments, and makes them executable. One command, done. Templates should contain actual commands for the detected language/build system.

### `fun-ci install-hook [pre-commit|pre-push]`

Wires up the git hook. The TUI empty state already mentions this command, so it's a promise the UI is already making.

### `fun-ci check`

Validates the current setup without running anything. Confirms `.fun-ci/` exists, scripts are present and executable, hook is installed. Gives people a way to verify their setup after manual edits.
