# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stage_runner"

STAGE_COMMIT = FunCi::Pipeline::Commit.new(sha: "abc123", branch: "main") unless defined?(STAGE_COMMIT)
require_relative "../support/fake_stage_dir"

# A stage that fails or overruns has its evidence kept before its outcome is
# recorded, so anyone who sees the outcome can read why (AT-9.5, AT-10.1).
class TestStageRunnerOutput < Minitest::Test
  Config = Data.define(:dir) do
    def stage_command(stage, sha) = "#{stage}.sh #{sha}"
  end

  def test_keeps_the_output_of_a_stage_that_failed
    recorder = recorded(->(_cmd) { ["boom\n", FakeStatus.new(false, 1)] })

    assert_equal "boom\n", recorder.kept_evidence.first.tail
  end

  def test_records_the_process_the_stage_runs_in
    recorder = recorded(lambda { |_cmd, &on_start|
      on_start.call(4242)
      ["", FakeStatus.new(true, 0)]
    })

    assert_includes recorder.calls, [:stage_process, 1, 4242]
  end

  def test_names_the_stage_to_its_script
    seen = nil
    recorded(->(_cmd, env) { (seen = env) && ["", FakeStatus.new(true, 0)] })

    assert_equal "fast", seen["FUN_CI_STAGE"]
  end

  def test_gives_an_injected_runner_the_stage_s_environment
    seen = nil
    recorded(->(_cmd, env) { (seen = env) && ["", FakeStatus.new(true, 0)] }, environment: { "HOME" => "/home/dev" })

    assert_equal "/home/dev", seen["HOME"]
  end

  def test_closes_the_stage_s_window_once_it_is_recorded
    stage_dir = FakeStageDir.new
    recorded(->(_cmd) { ["", FakeStatus.new(true, 0)] }, stage_dir)

    assert_equal [true], stage_dir.windows.map(&:closed?)
  end

  def test_removes_the_stage_directory_after_the_stage
    stage_dir = FakeStageDir.new
    recorded(->(_cmd) { ["", FakeStatus.new(true, 0)] }, stage_dir)

    assert stage_dir.removed
  end

  private

  def recorded(runner, stage_dir = FakeStageDir.new, environment: {})
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, recorder: recorder, stage_dir: -> { stage_dir },
                                       environment: environment)
    FunCi::Pipeline::StageRunner.new(commit: STAGE_COMMIT, stdout: StringIO.new, seams: seams)
                                .passes?(Config.new(dir: "/p"), "fast")
    recorder
  end
end

# A stage starts with its budget recorded, which `fun-ci why` reads back (AT-10.1).
class TestStageRunnerBudget < Minitest::Test
  Config = Data.define(:dir) do
    def stage_command(stage, sha) = "#{stage}.sh #{sha}"
  end

  def test_should_record_the_budget_a_stage_starts_with
    recorder = FakeRecorder.new
    seams = FunCi::Pipeline::Seams.new(command_runner: ->(_cmd) { ["", FakeStatus.new(true, 0)] }, recorder: recorder,
                                       stage_dir: -> { FakeStageDir.new }, time_budgets: { "fast" => 7 })
    FunCi::Pipeline::StageRunner.new(commit: STAGE_COMMIT, stdout: StringIO.new, seams: seams)
                                .passes?(Config.new(dir: "/p"), "fast")

    assert_equal({ "fast" => 7 }, recorder.budgets)
  end
end
