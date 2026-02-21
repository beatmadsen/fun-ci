# fun-ci Roadmap

Does not include completed work.

## Unified command-line interface for all fun-ci operations. 

Instead of having separate commands for different operations, we can have a single `fun-ci` command with subcommands for different tasks. This makes it easier to discover and use the various features of fun-ci without needing to remember multiple command names. This includes the trigger andn the tui.

`fun-ci trigger` and `fun-ci admin-ui` to replace the current `fun-ci-trigger` and `fun-ci-tui` commands. Their behaviour is still the same, this is solely about the entrypoint command name.

## Non validating invocation of the trigger

Introduce `fun-ci trigger --no-validate` which spawns the background process, but doesn't poll for the success of the initial stages of the job, instead it returns return code 0 immediately after successfully starting the background process. 

The user will keep track of the commit's success or failure through the TUI.

This is suitable for a pre-commit hook, since a use would sometimes want to commit code in a broken state as part of work in progress. The pre-push hook would still use the validating invocation, since the user is trying to push code that should be in a good state.

## Smart installer

A command that sets up fun-ci for a project, including creating the `.fun-ci/` folder and populating it with template scripts suitable for the project's language and build system.

We can't have templates for everything, but we can build an extensible system that I can build up over time, starting with the languages and build systems I'm most familiar with.

Things I know I will need at this pont:
- ruby bundle, have a look at my projects in ~/Developer/hobby/ruby and ~/Developer/hobby/rails for examples
- jvm gradle: kotlin and groovy flavours
- jvm maven, typically using surefire for unit/fast tests and failsafe for integration/slow tests

### `fun-ci init`

Creates `.fun-ci/`, generates real working template scripts (not stubs) with comments, and makes them executable. One command, done. Templates should contain actual commands for the detected language/build system.

### `fun-ci install-hooks`

Wires up the git hooks. The TUI empty state already mentions this command (make sure it mentions the updated syntax), so it's a promise the UI is already making.

The pre-commit hook should use the non-validating trigger, and the pre-push hook should use the validating trigger.

### `fun-ci check`

Validates the current setup without running anything. Confirms `.fun-ci/` exists, scripts are present and executable, hook is installed. Gives people a way to verify their setup after manual edits.

### `fun-ci init --everything`
Does (the equivalent of) `fun-ci init` followed by (the equivalent of) `fun-ci install-hooks`. And validates the setup with (the equivalent of) `fun-ci check` at the end. A simple command for 80% of users to get started with a working setup in one step. The other 20% can still use the individual commands for more control.


### Install gem locally on the system
System wide. `gem install fun-ci` should work and install the `fun-ci` command globally on the system, so I can start manual testing of the unified command-line interface and the smart installer.