# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

class TestTriggerArgumentParsing < Minitest::Test
  def test_should_return_nonzero_when_no_args_given
    refute_equal 0, run_from_args([])
  end

  def test_should_mention_commit_when_only_one_arg_given
    run_from_args(["main"])

    assert_match(/commit/i, @stderr.string)
  end

  def test_should_mention_branch_when_only_commit_given
    run_from_args(["abc1234"])

    assert_match(/branch/i, @stderr.string)
  end

  private

  def run_from_args(args)
    @stderr = StringIO.new
    FunCi::Pipeline::Trigger.run_from_args(args, io: FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: @stderr))
  end
end

class TestTriggerScriptExecution < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  %w[lint build fast slow].each do |stage|
    define_method(:"test_should_invoke_#{stage}_script_with_commit_hash") do
      assert_match(/abc1234/, runner_after.command_for("#{stage}.sh"))
    end
  end

  def test_should_invoke_slow_suite_even_when_fast_fails
    assert runner_after({ "fast.sh" => failing("test failed") }).ran?("slow.sh")
  end

  def test_should_still_run_build_when_lint_fails
    assert runner_after({ "lint.sh" => failing("lint errors found") }).ran?("build.sh")
  end

  private

  def runner_after(answers = {})
    runner = scripted_runner(answers)
    in_project { |dir| build_trigger(dir, command_runner: runner, background_launcher: inline_launcher).run }
    runner
  end
end

class TestTriggerRecording < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_record_lint_stage_via_recorder
    assert_includes calls_recorded, [:start_stage, "lint"]
  end

  def test_should_pass_project_root_as_project_path_to_recorder
    create_run = calls_recorded.find { |call| call.first == :create_run }

    assert_equal [:create_run, "abc1234", "main", @dir], create_run
  end

  def test_should_record_the_run_as_failed_when_the_slow_suite_fails
    assert_includes calls_recorded({ "slow.sh" => failing("slow test failed") }), [:fail_run]
  end

  def test_should_not_record_the_run_as_completed_when_the_slow_suite_fails
    refute_includes calls_recorded({ "slow.sh" => failing("slow test failed") }), [:complete_run]
  end

  private

  def calls_recorded(answers = {})
    recorder = FakeRecorder.new
    in_project do |dir|
      @dir = dir
      build_trigger(dir, command_runner: scripted_runner(answers), recorder: recorder,
                         background_launcher: inline_launcher(recorder)).run
    end
    recorder.calls
  end
end
