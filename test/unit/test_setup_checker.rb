# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/setup_checker"
require "tmpdir"
require "stringio"

class TestSetupCheckerWithIssues < Minitest::Test
  def test_should_report_missing_fun_ci_folder_to_stdout
    # Given a project directory without .fun-ci/
    Dir.mktmpdir("fun-ci-check-test") do |dir|
      stdout = StringIO.new

      # When we run the checker
      FunCi::Setup::SetupChecker.run(project_root: dir, stdout: stdout)

      # Then stdout should mention the missing .fun-ci folder
      assert_match(/\.fun-ci/, stdout.string, "Should report missing .fun-ci folder")
    end
  end

  def test_should_return_one_when_issues_found
    # Given a project directory without .fun-ci/
    Dir.mktmpdir("fun-ci-check-test") do |dir|
      stdout = StringIO.new

      # When we run the checker
      exit_code = FunCi::Setup::SetupChecker.run(project_root: dir, stdout: stdout)

      # Then it should return failure exit code
      assert_equal 1, exit_code, "Should return 1 when issues found"
    end
  end
end

class TestSetupCheckerAllClear < Minitest::Test
  include FunCiTestProject

  def test_should_return_zero_when_all_clear
    # Given a fully configured project
    Dir.mktmpdir("fun-ci-check-test") do |dir|
      make_project_with_scripts(dir)
      stdout = StringIO.new

      # When we run the checker
      exit_code = FunCi::Setup::SetupChecker.run(project_root: dir, stdout: stdout)

      # Then it should return success exit code
      assert_equal 0, exit_code, "Should return 0 when all clear"
    end
  end

  def test_should_report_all_clear_when_no_validation_errors
    # Given a fully configured project
    Dir.mktmpdir("fun-ci-check-test") do |dir|
      make_project_with_scripts(dir)
      stdout = StringIO.new

      # When we run the checker
      FunCi::Setup::SetupChecker.run(project_root: dir, stdout: stdout)

      # Then stdout should report a positive status
      assert_match(/ok|configured|ready/i, stdout.string, "Should report positive status")
    end
  end
end
