# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

class TestTriggerStageFailures < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_fail_the_run_when_lint_fails
    refute_equal 0, run_with({ "lint.sh" => failing("lint errors found") }).exit_code
  end

  def test_should_say_lint_failed_when_lint_fails
    assert_includes run_with({ "lint.sh" => failing("lint errors found") }).stdout, "Lint failed."
  end

  %w[lint build fast].each do |stage|
    define_method(:"test_should_fail_the_run_when_#{stage}_exceeds_its_budget") do
      refute_equal 0, run_with({ "#{stage}.sh" => Timeout::Error }).exit_code
    end

    define_method(:"test_should_name_the_budget_when_#{stage}_exceeds_it") do
      assert_match(/exceeded \d+s time budget/, run_with({ "#{stage}.sh" => Timeout::Error }).stdout)
    end
  end

  private

  def run_with(answers) = run_in_project(command_runner: scripted_runner(answers))
end

class TestTriggerCommitValidation < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_fail_when_the_commit_is_unknown
    refute_equal 0, run_unknown_commit.exit_code
  end

  def test_should_say_the_commit_was_not_found_when_it_is_unknown
    assert_includes run_unknown_commit.stderr, "commit deadbeef not found"
  end

  def test_should_pass_the_null_sha_of_a_root_commit_without_validating_it
    outcome = run_in_project(sha: "0" * 40, command_runner: scripted_runner, commit_validator: rejecting)

    assert_equal 0, outcome.exit_code
  end

  def test_should_run_the_stages_for_the_null_sha_of_a_root_commit
    runner = scripted_runner
    run_in_project(sha: "0" * 40, command_runner: runner, commit_validator: rejecting)

    assert runner.ran?("lint.sh")
  end

  private

  def rejecting = ->(_sha) { false }
  def run_unknown_commit = run_in_project(sha: "deadbeef", commit_validator: rejecting)
end

class TestTriggerMissingFunCiFolder < Minitest::Test
  include TriggerTestKit

  def test_should_exit_zero_so_the_commit_proceeds_when_there_is_no_fun_ci_folder
    assert_equal 0, run_without_folder.exit_code
  end

  def test_should_say_the_folder_is_missing_when_there_is_no_fun_ci_folder
    assert_match(%r{No \.fun-ci/ folder found}i, run_without_folder.stdout)
  end

  def test_should_suggest_creating_scripts_when_no_fun_ci_folder
    assert_match(/lint\.sh.*build\.sh.*fast\.sh.*slow\.sh/m, run_without_folder.stdout)
  end

  private

  def run_without_folder
    io = quiet_io
    exit_code = Dir.mktmpdir("fun-ci-test") { |dir| build_trigger(dir, io: io).run }
    Outcome.new(exit_code, io.stdout.string, io.stderr.string)
  end
end
