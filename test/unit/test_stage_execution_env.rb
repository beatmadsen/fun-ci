# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/stage_execution"
require "fun_ci/pipeline/trigger_params"
require_relative "../support/fake_stage_dir"

# What a script run through StageExecution is told about itself: a stage its
# name, or whatever its caller names in its place, as a job is told its own
# (acceptance-tests.md, AT-10.7, AT-13.8).
class TestStageExecutionEnv < Minitest::Test
  COMMIT = FunCi::Pipeline::Commit.new(sha: "abc123", branch: "main")

  def test_should_tell_a_script_run_with_variables_of_its_own_those
    seen = environment_seen(launching: { env: { "FUN_CI_JOB" => "mutation" } })

    assert_equal "mutation", seen["FUN_CI_JOB"]
  end

  def test_should_not_name_a_stage_to_a_script_run_with_variables_of_its_own
    seen = environment_seen(launching: { env: { "FUN_CI_JOB" => "mutation" } })

    refute seen.key?("FUN_CI_STAGE")
  end

  def test_should_name_the_stage_to_its_script_by_default
    seen = environment_seen

    assert_equal "fast", seen["FUN_CI_STAGE"]
  end

  private

  def environment_seen(**given)
    seen = nil
    runner = ->(_cmd, env) { (seen = env) && ["", FakeStatus.new(true, 0)] }
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, stage_dir: -> { FakeStageDir.new }, environment: {})
    FunCi::Pipeline::StageExecution.new(seams: seams, dir: "/p", commit: COMMIT, **given)
                                   .run("fast", "fast.sh abc123", FakeRecorder.new, 1)
    seen
  end
end
