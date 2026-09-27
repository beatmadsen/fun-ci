# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/evidence/settings"

# `fun-ci check` reports a `run:` entry whose script is missing or can't be
# run (architecture.md, "Evidence of a failed stage").
class TestEvidenceCommandCheck < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, ".fun-ci", "evidence"))
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_should_report_a_script_that_does_not_exist
    assert_equal ["evidence.stages.fast: run:.fun-ci/evidence/gone: .fun-ci/evidence/gone doesn't exist"],
                 errors(".fun-ci/evidence/gone")
  end

  def test_should_report_a_script_that_is_not_executable
    File.write(File.join(@root, ".fun-ci", "evidence", "x"), "#!/bin/sh\n")

    assert_equal ["evidence.stages.fast: run:.fun-ci/evidence/x --verbose: .fun-ci/evidence/x isn't executable"],
                 errors(".fun-ci/evidence/x --verbose")
  end

  def test_should_leave_a_command_on_the_path_alone
    assert_empty errors("grep -B2 -A20 'Caused by' build/test.log")
  end

  private

  def errors(command)
    FunCi::Evidence::Settings.new({ "stages" => { "fast" => [{ "run" => command }] } }).errors(root: @root)
  end
end
