# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "tmpdir"
require "fun_ci/pipeline/trigger"

# Tests for Phase 2: fast (blocking) + slow (background) start simultaneously.
# The slow suite should be spawned at the start of Phase 2, not after fast completes.

class TestTriggerParallelPhaseTwo < Minitest::Test
  include FunCiTestProject

  def test_should_spawn_slow_before_fast_completes
    # Given a project where all stages pass, with an event log
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      events = []
      fake_runner = ->(cmd) {
        events << [:run, cmd]
        ["", FakeStatus.new(true, 0)]
      }
      launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
        events << [:spawn_slow]
        FunCi::Pipeline::BackgroundWrapper.new(
          recorder: FakeRecorder.new, job_id: job_id, executor: executor
        ).run
      }
      trigger = FunCi::Pipeline::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        stderr: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        background_launcher: launcher
      )
      # When the trigger is run
      trigger.run
      # Then the slow suite spawn should happen before fast completes
      spawn_idx = events.index { |e| e[0] == :spawn_slow }
      fast_idx = events.index { |e| e[0] == :run && e[1].include?("fast.sh") }
      refute_nil spawn_idx, "Should spawn slow suite"
      refute_nil fast_idx, "Should run fast suite"
      assert spawn_idx < fast_idx,
        "Slow suite should be spawned before fast suite completes"
    end
  end

  def test_should_fail_when_fast_fails_even_with_parallel_slow
    # Given a project where fast fails
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        if cmd.include?("fast.sh")
          ["fast test failed", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {}
      trigger = FunCi::Pipeline::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        stderr: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        background_launcher: launcher
      )
      # When the trigger is run
      exit_code = trigger.run
      # Then the exit code should be non-zero (fast failure blocks)
      refute_equal 0, exit_code, "Should fail when fast suite fails"
    end
  end
end
