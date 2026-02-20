# fun-ci Roadmap

Does not include completed work.

## Linter stage before build stage

## Running some stages in parallel

The tests will depend on the build stage.

So we can run linter and build in parallel first, and then run the test suites in parallel after the build stage completes successfully. This will speed up feedback and make better use of our time budgets.

## Trigger invocation gives some feedack

When you trigger a run, you should poll on the outcomes all the way up the end of the fast suite. 

It will not wait for the slow suite. The idea is to give a git hook some preliminary, timely gate to prevent bad code from being merged, but the slow suite is more of a safety net and can be allowed to run in the background after the fact.

## Smart installer

A command that sets up fun-ci for a project, including creating the `.fun-ci/` folder and populating it with template scripts suitable for the project's language and build system.

We can't have templates for everything, but we can build an extensible system that I can build up over time, starting with the languages and build systems I'm most familiar with.

Things I know I will need at this pont:
- ruby bundle, have a look at my projects in ~/Developer/hobby/ruby and ~/Developer/hobby/rails for examples
- jvm gradle: kotlin and groovy flavours
- jvm maven, typically using surefire for unit/fast tests and failsafe for integration/slow tests