# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup_checker"
require "tmpdir"
require "stringio"

class TestCheckCliUnconfigured < Minitest::Test
  def test_should_report_missing_fun_ci_folder
    # Given an unconfigured project (no .fun-ci/ folder)
    Dir.mktmpdir("fun-ci-check-test") do |dir|
      stdout = StringIO.new
      stderr = StringIO.new

      # When we run the check command
      exit_code = FunCi::SetupChecker.run(project_root: dir, stdout: stdout, stderr: stderr)

      # Then it should report the missing folder and return failure
      assert_equal 1, exit_code, "Should return failure exit code"
      assert_match(/\.fun-ci/, stdout.string, "Should mention missing .fun-ci folder")
    end
  end
end
