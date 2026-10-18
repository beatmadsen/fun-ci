# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/stage_templates"

# Lint runs beside the build, which installs the packages (design.md, Stages
# side by side), so a JavaScript stack's lint checks the source alone: a
# linter that loads packages, ESLint, raced the install in a new worktree
# and failed on a plugin it couldn't find. ESLint runs in the build, after
# the install (EslintDetection).
class TestJavascriptTemplates < Minitest::Test
  NODE_CHECK = "find . -name node_modules -prune -o -name .git -prune -o -type f " \
               "\\( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \\) -print | " \
               'while read -r file; do node --check "$file" || exit 1; done'
  BUN_CHECK = "find . -name node_modules -prune -o -name .git -prune -o -type f " \
              "\\( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' \\) -print | " \
              'while read -r file; do bun build --no-bundle "$file" > /dev/null || exit 1; done'
  LINTS = { node_npm: NODE_CHECK, node_pnpm: NODE_CHECK, node_yarn: NODE_CHECK, bun: BUN_CHECK }.freeze
  INSTALLS = { node_npm: "npm install", node_pnpm: "pnpm install", node_yarn: "yarn install",
               bun: "bun install" }.freeze

  LINTS.each do |template, command|
    define_method(:"test_should_check_#{template}_source_without_its_packages") do
      assert_equal command, command_in(template, "lint.sh")
    end
  end

  INSTALLS.each do |template, command|
    define_method(:"test_should_only_install_#{template}_packages_in_the_build_when_nothing_else_is_known") do
      assert_equal command, command_in(template, "build.sh")
    end
  end

  def test_should_say_which_stage_a_build_override_runs_beside
    scripts = FunCi::Setup::StageTemplates.scripts(:node_npm, build_override: "npm install && npx eslint .")

    assert_equal "#!/bin/sh\n# Runs beside lint.sh; then fast.sh and slow.sh run side by side on what it builds.\n" \
                 "npm install && npx eslint .\n", scripts["build.sh"]
  end

  private

  def command_in(template, script) = FunCi::Setup::StageTemplates.scripts(template)[script].lines.last.chomp
end
