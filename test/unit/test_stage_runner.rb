# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stage_runner"

class TestStageRunnerDefaults < Minitest::Test
  def test_builds_without_a_recorder
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new)
  end

  def test_records_nothing_when_built_without_a_recorder
    runner = FunCi::Pipeline::StageRunner.new(
      commit_hash: "abc123", stdout: StringIO.new, command_runner: passing_runner
    )

    assert runner.run_stage(config, "lint")
  end

  private

  def passing_runner
    ->(*) { ["", Struct.new(:success?).new(true), false] }
  end

  def config
    Class.new { def script_path(stage) = "#{stage}.sh" }.new
  end
end
