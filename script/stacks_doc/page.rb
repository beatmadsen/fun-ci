# frozen_string_literal: true

require_relative "stack_table"
require_relative "preset_table"

module StacksDoc
  # docs/stacks.md: the prose around the two tables.
  module Page
    INTRO = <<~MD.chomp
      # Stacks and presets

      This page lists what fun-ci knows about each stack: how `fun-ci init` recognises it, the four stage scripts it writes, and the presets that pick a tool's failures out of a failed stage's output. `ruby script/stacks_doc.rb` draws it from the code, and a test fails when the two disagree, so change the code and run the script rather than editing the page.
    MD

    INIT = <<~MD.chomp
      ## What `fun-ci init` writes

      `fun-ci init` looks at the names at the top of your project and takes the first stack in this table that has one of its markers there. A Python project with a `package.json` for its front end is set up as Python, and a Go project with a `Makefile` as Go. The scripts are plain shell and a starting point, so edit them to run whatever your project uses.

      The fast suite leaves out the tests the tool's own convention marks slow, and the slow suite runs only those (for Maven, failsafe's integration tests, the classes named `*IT`). Where the tool has no such convention, the slow suite is a `test:slow` script (a `test-slow` target for make). A slow suite with no tests in it passes having run nothing under cargo, dotnet, Maven, PHPUnit, rspec and swift, and fails under the others, until you edit `slow.sh`.

      Lint runs beside build on the checkout, and the two suites run beside each other on what build made ([Stages side by side](design.md#stages-side-by-side)). So each `lint.sh` works on the source alone, each `build.sh` compiles the test code too, and no suite builds: where a tool would compile as it tests, the suites skip it. For Maven, lint runs the source linter the POM configures (detekt, ktlint, checkstyle or PMD), else `mvn validate`; for Gradle, the one the build applies (ktlint, spotless or detekt), else none. A linter that reads compiled classes, such as spotbugs, goes in `build.sh` after compiling, or in `fast.sh`.

      Maven's slow suite calls failsafe's goals directly, so declare the failsafe plugin in the POM to fix its version, and move anything bound to `pre-integration-test` (a container, a server) into `slow.sh`. Gradle's `testClasses` compiles the `test` source set; an `integrationTest` with a source set of its own needs its classes task (`integrationTestClasses`) added to `build.sh`.
    MD

    PRESETS = <<~MD.chomp
      ## Presets

      When a stage fails, fun-ci runs the presets that apply, with no configuration. A preset applies when the project has one of its marker files (or the preset has none) and the stage's output has a line only its tool prints. Each is checked against the recorded output of a real failing run of its tool, kept in `test/fixtures/evidence/`. `fun-ci check` lists the presets that apply to your project and `fun-ci why` says why each one ran. To keep more than the presets pick out, add entries under `evidence:` in `.fun-ci/config`, as the README shows.
    MD

    def self.markdown = "#{[INTRO, INIT, StackTable.markdown, PRESETS, PresetTable.markdown].join("\n\n")}\n"
  end
end
