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
      assert_match(/abc1234/, invocation_of("#{stage}.sh"))
    end
  end

  def test_should_invoke_slow_suite_even_when_fast_fails
    refute_nil invocation_of("slow.sh", "fast.sh" => failing("test failed"))
  end

  def test_should_still_run_build_when_lint_fails
    refute_nil invocation_of("build.sh", "lint.sh" => failing("lint errors found"))
  end

  private

  def invocation_of(script, answers = {})
    log = []
    in_project do |dir|
      build_trigger(dir, command_runner: scripted_runner(answers, log: log), background_launcher: inline_launcher).run
    end
    log.find { |cmd| cmd.include?(script) }
  end
end

class TestTriggerStageFailures < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_a_failing_lint_fails_the_run_and_says_so
    exit_code, output = run_with("lint.sh" => failing("lint errors found"))

    refute_equal 0, exit_code
    assert_match(/Lint failed/, output)
  end

  %w[lint build fast].each do |stage|
    define_method(:"test_a_#{stage}_stage_over_budget_fails_the_run_and_names_the_budget") do
      exit_code, output = run_with("#{stage}.sh" => Timeout::Error)

      refute_equal 0, exit_code
      assert_match(/time budget/i, output)
    end
  end

  private

  def run_with(answers)
    io = quiet_io
    exit_code = in_project { |dir| build_trigger(dir, io: io, command_runner: scripted_runner(answers)).run }
    [exit_code, io.stdout.string]
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

  def test_should_call_fail_run_when_slow_suite_fails
    calls = calls_recorded("slow.sh" => failing("slow test failed"))

    assert_includes calls, [:fail_run]
    refute_includes calls, [:complete_run]
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

class TestTriggerCommitValidation < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_reject_invalid_commit_hash
    io = quiet_io
    exit_code = in_project { |dir| build_trigger(dir, sha: "deadbeef", io: io, commit_validator: ->(_) { false }).run }

    refute_equal 0, exit_code
    assert_match(/not found/i, io.stderr.string)
  end

  def test_should_skip_validation_for_null_sha_on_root_commit
    log = []
    exit_code = in_project do |dir|
      build_trigger(dir, sha: "0" * 40, command_runner: scripted_runner(log: log),
                         commit_validator: ->(_) { false }).run
    end

    assert_equal 0, exit_code
    assert(log.any? { |cmd| cmd.include?("lint.sh") })
  end
end

class TestTriggerMissingFunCiFolder < Minitest::Test
  include TriggerTestKit

  def test_should_exit_zero_and_say_the_folder_is_missing
    exit_code, output = run_without_folder

    assert_equal 0, exit_code
    assert_match(%r{No \.fun-ci/ folder found}i, output)
  end

  def test_should_suggest_creating_scripts_when_no_fun_ci_folder
    assert_match(/lint\.sh.*build\.sh.*fast\.sh.*slow\.sh/m, run_without_folder.last)
  end

  private

  def run_without_folder
    io = quiet_io
    exit_code = Dir.mktmpdir("fun-ci-test") { |dir| build_trigger(dir, io: io).run }
    [exit_code, io.stdout.string]
  end
end
