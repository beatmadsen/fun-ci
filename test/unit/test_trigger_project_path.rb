# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "tmpdir"
require "fun_ci/trigger"

class TestTriggerProjectPath < Minitest::Test
  include FunCiTestProject

  def test_should_pass_project_root_as_project_path_to_recorder
    # Given a project with valid scripts and a recorder that captures calls
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      recorder = FakeRecorder.new
      fake_runner = ->(_cmd, _opts = {}) { ["", FakeStatus.new(true, 0)] }
      launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
        FunCi::BackgroundWrapper.new(
          recorder: FakeRecorder.new, job_id: job_id, executor: executor
        ).run
      }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        stderr: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: recorder,
        background_launcher: launcher
      )
      # When the trigger runs
      trigger.run
      # Then the recorder should have received project_path matching project_root
      create_call = recorder.calls.find { |c| c[0] == :create_run }
      refute_nil create_call, "Should call create_run"
      assert_equal dir, create_call[3], "Should pass project_root as project_path to recorder"
    end
  end
end
