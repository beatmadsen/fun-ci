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

  def test_a_stage_over_budget_is_told_how_to_get_back_under_it
    stdout = StringIO.new
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { raise Timeout::Error })
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: stdout, seams: seams).passes?(config, "fast")

    assert_includes stdout.string, "Your fast tests have gotten too slow. Split or speed them up."
  end

  def test_runs_the_stage_s_script_with_the_commit_hash_as_its_argument
    commands = []
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(cmd) { (commands << cmd) && ["", FakeStatus.new(true, 0)] })
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams).passes?(config, "lint")

    assert_equal ["lint.sh abc123"], commands
  end

  def test_records_the_stage_starting
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: passing_runner, recorder: recorder)
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams).passes?(config, "lint")

    assert_equal [:start_stage, "lint"], recorder.calls.first
  end

  def test_a_stage_over_budget_fails
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { raise Timeout::Error })

    refute FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams).passes?(config,
                                                                                                               "lint")
  end

  def test_a_stage_over_budget_is_recorded_as_timed_out
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { raise Timeout::Error }, recorder: recorder)
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams).passes?(config, "lint")

    assert_equal [:end_stage, 1, "timed_out"], recorder.calls.last
  end

  def test_says_which_stage_failed_when_its_script_fails
    assert_includes output_of_failing("build"), "Build failed."
  end

  def test_shows_what_a_failing_script_printed
    assert_includes output_of_failing("build"), "undefined method"
  end

  def test_a_script_that_exits_nonzero_fails_the_stage
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { failing_answer })

    refute FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: StringIO.new, seams: seams).passes?(config,
                                                                                                               "lint")
  end

  private

  def failing_answer = ["undefined method `x'", FakeStatus.new(false, 1)]

  def output_of_failing(stage)
    stdout = StringIO.new
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { failing_answer })
    FunCi::Pipeline::StageRunner.new(commit_hash: "abc123", stdout: stdout, seams: seams).passes?(config, stage)
    stdout.string
  end

  def passing_runner
    ->(_cmd) { ["", FakeStatus.new(true, 0)] }
  end

  def config
    Class.new { def script_path(stage) = "#{stage}.sh" }.new
  end
end
