# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stage_runner"

class TestStageRunnerDefaults < Minitest::Test
  def test_records_nothing_when_built_without_a_recorder
    runner = FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new,
                                              seams: FunCi::Pipeline::Seams.new(command_runner: passing_runner))

    assert runner.passes?(config, "lint")
  end

  def test_a_stage_without_a_budget_of_its_own_gets_the_default_one
    stdout = StringIO.new
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { raise Timeout::Error })
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: stdout, seams: seams).passes?(config, "fast")

    assert_match(/exceeded 10s time budget/, stdout.string)
  end

  private

  def passing_runner
    ->(_cmd) { ["", FakeStatus.new(true, 0)] }
  end

  def config
    Class.new { def script_path(stage) = "#{stage}.sh" }.new
  end
end
