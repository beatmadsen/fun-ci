# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/setup_checker"
require "stringio"

# `fun-ci check`: report what ProjectConfig found wrong, or that all is well.
class TestSetupChecker < Minitest::Test
  Config = Struct.new(:validate)
  Hooks = Struct.new(:warnings)
  PROBLEMS = [".fun-ci/lint.sh is not found", ".fun-ci/fast.sh is not executable"].freeze

  def test_should_fail_when_the_project_has_problems
    assert_equal 1, check(PROBLEMS)
  end

  def test_should_list_each_problem_on_its_own_line
    check(PROBLEMS)

    assert_equal PROBLEMS, @stdout.string.lines(chomp: true)
  end

  def test_should_pass_when_the_project_has_no_problems
    assert_equal 0, check([])
  end

  def test_should_say_the_project_is_configured_when_it_has_no_problems
    check([])

    assert_equal "All OK. The project is configured.\n", @stdout.string
  end

  def test_should_still_pass_with_only_warnings
    assert_equal 0, check([], warnings: ["hook calls fun-ci"])
  end

  def test_should_print_each_warning_after_the_verdict
    check([], warnings: ["hook calls fun-ci"])

    assert_equal "All OK. The project is configured.\nWarning: hook calls fun-ci\n", @stdout.string
  end

  private

  def check(problems, warnings: [])
    @stdout = StringIO.new
    FunCi::Setup::SetupChecker.new(config: Config.new(problems), hooks: Hooks.new(warnings), stdout: @stdout).run
  end
end
