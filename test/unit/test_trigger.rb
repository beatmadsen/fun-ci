# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "tmpdir"
require "fun_ci/trigger"

class TestTriggerArgumentParsing < Minitest::Test
  def test_should_return_nonzero_when_no_args_given
    # Given no arguments
    stderr = StringIO.new
    # When run_from_args is called with empty args
    exit_code = FunCi::Trigger.run_from_args([], stderr: stderr)
    # Then exit code should be non-zero
    refute_equal 0, exit_code, "Should reject empty arguments"
  end

  def test_should_mention_commit_when_only_one_arg_given
    # Given only one argument (treated as branch, missing commit)
    stderr = StringIO.new
    # When run_from_args is called with one arg
    FunCi::Trigger.run_from_args(["main"], stderr: stderr)
    # Then stderr should mention the missing commit
    assert_match(/commit/i, stderr.string, "Should mention missing commit hash")
  end

  def test_should_mention_branch_when_only_commit_given
    # Given only a commit hash (missing branch)
    stderr = StringIO.new
    # When run_from_args is called with one arg
    FunCi::Trigger.run_from_args(["abc1234"], stderr: stderr)
    # Then stderr should mention the missing branch
    assert_match(/branch/i, stderr.string, "Should mention missing branch name")
  end
end

class TestTriggerScriptExecution < Minitest::Test
  include FunCiTestProject

  def make_trigger(dir, commit_hash: "abc1234", command_runner: nil)
    stdout = StringIO.new
    stderr = StringIO.new
    launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
      FunCi::BackgroundWrapper.new(
        recorder: FakeRecorder.new, job_id: job_id, executor: executor
      ).run
    }
    trigger = FunCi::Trigger.new(
      project_root: dir,
      commit_hash: commit_hash,
      branch: "main",
      stdout: stdout,
      stderr: stderr,
      command_runner: command_runner,
      commit_validator: ->(_h) { true },
      background_launcher: launcher
    )
    [trigger, stdout, stderr]
  end

  def test_should_invoke_build_script_with_commit_hash
    # Given a project with valid scripts and a fake command runner
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd, _opts = {}) {
        invocations << cmd
        ["", FakeStatus.new(true, 0)]
      }
      trigger, = make_trigger(dir, commit_hash: "abc1234", command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then build.sh should have been invoked with the commit hash
      build_cmd = invocations.find { |cmd| cmd.include?("build.sh") }
      refute_nil build_cmd, "Should invoke build.sh"
      assert_match(/abc1234/, build_cmd, "Should pass commit hash to build.sh")
    end
  end

  def test_should_invoke_slow_suite_after_fast_passes
    # Given a project with all scripts passing
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd, _opts = {}) {
        invocations << cmd
        ["", FakeStatus.new(true, 0)]
      }
      trigger, = make_trigger(dir, commit_hash: "abc1234", command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then slow.sh should have been invoked
      slow_cmd = invocations.find { |cmd| cmd.include?("slow.sh") }
      refute_nil slow_cmd, "Should invoke slow.sh after fast passes"
      assert_match(/abc1234/, slow_cmd, "Should pass commit hash to slow.sh")
    end
  end

  def test_should_invoke_slow_suite_even_when_fast_fails
    # Given a project where fast.sh fails (slow starts before fast in Phase 2)
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd, _opts = {}) {
        invocations << cmd
        if cmd.include?("fast.sh")
          ["test failed", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, = make_trigger(dir, commit_hash: "abc1234", command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then slow.sh should have been invoked (parallel Phase 2)
      slow_cmd = invocations.find { |cmd| cmd.include?("slow.sh") }
      refute_nil slow_cmd, "Slow should run even when fast fails (parallel Phase 2)"
    end
  end
end

class TestTriggerLintStage < Minitest::Test
  include FunCiTestProject

  def make_trigger(dir, commit_hash: "abc1234", command_runner: nil, time_budgets: {})
    stdout = StringIO.new
    stderr = StringIO.new
    launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
      FunCi::BackgroundWrapper.new(
        recorder: FakeRecorder.new, job_id: job_id, executor: executor
      ).run
    }
    trigger = FunCi::Trigger.new(
      project_root: dir,
      commit_hash: commit_hash,
      branch: "main",
      stdout: stdout,
      stderr: stderr,
      command_runner: command_runner,
      commit_validator: ->(_h) { true },
      background_launcher: launcher,
      time_budgets: time_budgets
    )
    [trigger, stdout, stderr]
  end

  def test_should_invoke_lint_script_with_commit_hash
    # Given a project with valid scripts and a fake command runner
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        ["", FakeStatus.new(true, 0)]
      }
      trigger, = make_trigger(dir, commit_hash: "abc1234", command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then lint.sh should have been invoked with the commit hash
      lint_cmd = invocations.find { |cmd| cmd.include?("lint.sh") }
      refute_nil lint_cmd, "Should invoke lint.sh"
      assert_match(/abc1234/, lint_cmd, "Should pass commit hash to lint.sh")
    end
  end

  def test_should_invoke_both_lint_and_build_in_phase_one
    # Given a project with valid scripts and a runner that records invocations
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        ["", FakeStatus.new(true, 0)]
      }
      trigger, = make_trigger(dir, commit_hash: "abc1234", command_runner: fake_runner)
      # When the trigger is run
      trigger.run
      # Then both lint.sh and build.sh should have been invoked
      lint_cmd = invocations.find { |cmd| cmd.include?("lint.sh") }
      build_cmd = invocations.find { |cmd| cmd.include?("build.sh") }
      refute_nil lint_cmd, "Should invoke lint.sh"
      refute_nil build_cmd, "Should invoke build.sh"
    end
  end

  def test_should_still_run_build_when_lint_fails
    # Given a project where lint.sh fails (lint + build run in parallel)
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        if cmd.include?("lint.sh")
          ["lint errors found", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger, stdout, = make_trigger(dir, commit_hash: "abc1234", command_runner: fake_runner)
      # When the trigger is run
      exit_code = trigger.run
      # Then build.sh should still have been invoked (parallel Phase 1)
      build_cmd = invocations.find { |cmd| cmd.include?("build.sh") }
      refute_nil build_cmd, "Build should still run when lint fails (parallel)"
      # And exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when lint fails"
      # And stdout should mention lint failure
      assert_match(/Lint failed/i, stdout.string, "Should mention lint failure")
    end
  end

  def test_should_fail_when_lint_exceeds_time_budget
    # Given a project with a lint stage that times out
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        raise Timeout::Error, "simulated timeout" if cmd.include?("lint.sh")
        ["", FakeStatus.new(true, 0)]
      }
      trigger, stdout, = make_trigger(dir, commit_hash: "abc1234",
        command_runner: fake_runner, time_budgets: { "lint" => 1 })
      # When the trigger is run
      exit_code = trigger.run
      # Then exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when lint exceeds budget"
      # And stdout should mention the time budget
      assert_match(/time budget/i, stdout.string, "Should mention time budget exceeded")
    end
  end

  def test_should_record_lint_stage_via_recorder
    # Given a project with all scripts passing and a fake recorder
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      recorder = FakeRecorder.new
      fake_runner = ->(cmd) { ["", FakeStatus.new(true, 0)] }
      launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
        FunCi::BackgroundWrapper.new(
          recorder: recorder, job_id: job_id, executor: executor
        ).run
      }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: recorder,
        background_launcher: launcher
      )
      # When the trigger is run
      trigger.run
      # Then recorder should have recorded a lint stage
      lint_start = recorder.calls.find { |c| c[0] == :start_stage && c[1] == "lint" }
      refute_nil lint_start, "Should record lint stage start"
    end
  end
end

class TestTriggerTimeBudgets < Minitest::Test
  include FunCiTestProject

  def test_should_fail_when_build_exceeds_time_budget
    # Given a project with a build that times out
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        raise Timeout::Error, "simulated timeout" if cmd.include?("build.sh")
        ["", FakeStatus.new(true, 0)]
      }
      stdout = StringIO.new
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: stdout,
        time_budgets: { "build" => 1 },
        commit_validator: ->(_h) { true },
        command_runner: fake_runner
      )
      # When the trigger is run
      exit_code = trigger.run
      # Then exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when build exceeds budget"
      # And stdout should mention the time budget
      assert_match(/time budget/i, stdout.string, "Should mention time budget exceeded")
    end
  end

  def test_should_fail_when_fast_suite_exceeds_time_budget
    # Given a project with a fast suite that times out
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        raise Timeout::Error, "simulated timeout" if cmd.include?("fast.sh")
        ["", FakeStatus.new(true, 0)]
      }
      stdout = StringIO.new
      noop_launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {}
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: stdout,
        time_budgets: { "build" => 5, "fast" => 1 },
        commit_validator: ->(_h) { true },
        command_runner: fake_runner,
        background_launcher: noop_launcher
      )
      # When the trigger is run
      exit_code = trigger.run
      # Then exit code should be non-zero
      refute_equal 0, exit_code, "Should fail when fast suite exceeds budget"
      # And stdout should mention the time budget
      assert_match(/time budget/i, stdout.string, "Should mention time budget exceeded")
    end
  end
end


class TestTriggerCommitValidation < Minitest::Test
  include FunCiTestProject

  def test_should_reject_invalid_commit_hash
    # Given a project with valid scripts but a fake git that says commit is invalid
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      stdout = StringIO.new
      stderr = StringIO.new
      fake_git = ->(_commit) { false }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "deadbeef",
        branch: "main",
        stdout: stdout,
        stderr: stderr,
        commit_validator: fake_git
      )
      # When the trigger is run
      exit_code = trigger.run
      # Then exit code should be non-zero
      refute_equal 0, exit_code, "Should reject invalid commit"
      # And stderr should mention the commit
      assert_match(/not found/i, stderr.string, "Should say commit not found")
    end
  end

  def test_should_skip_validation_for_null_sha_on_root_commit
    # Given a project with valid scripts and a validator that rejects everything
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      null_sha = "0000000000000000000000000000000000000000"
      invocations = []
      fake_runner = ->(cmd) {
        invocations << cmd
        ["", FakeStatus.new(true, 0)]
      }
      noop_launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {}
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: null_sha,
        branch: "main",
        stdout: StringIO.new,
        stderr: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { false },
        background_launcher: noop_launcher
      )
      # When the trigger is run with the null SHA
      exit_code = trigger.run
      # Then the pipeline should proceed (exit 0)
      assert_equal 0, exit_code, "Should accept null SHA for root commits"
      # And at least one stage script should have been invoked
      assert invocations.any? { |cmd| cmd.include?("lint.sh") },
        "Should run the pipeline despite the null SHA"
    end
  end
end

class TestTriggerDatabasePersistence < Minitest::Test
  include FunCiTestProject
  include DatabaseTestSetup

  def setup
    require "fun_ci/database"
    require "fun_ci/pipeline_recorder"
    setup_test_db
    @recorder = FunCi::DbRecorder.new(@db)
  end

  def teardown
    teardown_test_db
  end

  private

  def sync_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
    recorder = FunCi::DbRecorder.for_background(db_path, pipeline_run_id)
    FunCi::BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
    recorder.close
  end

  public

  def test_should_create_pipeline_run_when_recorder_provided
    # Given a project with valid scripts, a fake runner, and a DB recorder
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) { ["", FakeStatus.new(true, 0)] }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: @recorder,
        background_launcher: method(:sync_launcher)
      )
      # When the trigger is run
      trigger.run
      # Then a pipeline_run record should exist in the database
      runs = FunCi::PipelineRun.find_by_commit(@db, "abc1234")
      refute_empty runs, "Should create a pipeline_run record"
      assert_equal "abc1234", runs.first[:commit_hash]
      assert_equal "main", runs.first[:branch]
    end
  end

  def test_should_create_stage_jobs_for_each_stage_when_recorder_provided
    # Given a project with all stages passing, a fake runner, and a DB recorder
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) { ["", FakeStatus.new(true, 0)] }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: @recorder,
        background_launcher: method(:sync_launcher)
      )
      # When the trigger is run
      trigger.run
      # Then stage_job records should exist for build, fast, and slow
      runs = FunCi::PipelineRun.find_by_commit(@db, "abc1234")
      jobs = @db.execute("SELECT stage FROM stage_jobs WHERE pipeline_run_id = ?", [runs.first[:id]])
      stages = jobs.map { |row| row[0] }
      assert_includes stages, "build", "Should create a stage_job for build"
      assert_includes stages, "fast", "Should create a stage_job for fast"
      assert_includes stages, "slow", "Should create a stage_job for slow"
    end
  end

  def test_should_update_pipeline_run_to_completed_when_all_stages_pass
    # Given a project with all stages passing and a DB recorder
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) { ["", FakeStatus.new(true, 0)] }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: @recorder,
        background_launcher: method(:sync_launcher)
      )
      # When the trigger is run
      trigger.run
      # Then the pipeline_run status should be "completed"
      run = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
      assert_equal "completed", run[:status], "Pipeline should be marked completed"
    end
  end

  def test_should_update_pipeline_run_to_failed_when_build_fails
    # Given a project where build fails and a DB recorder
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      fake_runner = ->(cmd) {
        if cmd.include?("build.sh")
          ["build error", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: @recorder
      )
      # When the trigger is run
      trigger.run
      # Then the pipeline_run status should be "failed"
      run = FunCi::PipelineRun.find_by_commit(@db, "abc1234").first
      assert_equal "failed", run[:status], "Pipeline should be marked failed"
    end
  end
end

class TestTriggerMissingFunCiFolder < Minitest::Test
  def test_should_print_missing_folder_message_when_no_fun_ci_folder
    # Given a project directory without a .fun-ci/ folder
    Dir.mktmpdir("fun-ci-test") do |dir|
      stdout = StringIO.new
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: stdout
      )
      # When the trigger is run
      exit_code = trigger.run
      # Then it should exit 0 (never block commits)
      assert_equal 0, exit_code, "Should exit 0 when no .fun-ci/ folder"
      # And stdout should mention the missing folder
      assert_match(/No \.fun-ci\/ folder found/i, stdout.string,
        "Should tell the developer the folder is missing")
    end
  end

  def test_should_suggest_creating_scripts_when_no_fun_ci_folder
    # Given a project directory without a .fun-ci/ folder
    Dir.mktmpdir("fun-ci-test") do |dir|
      stdout = StringIO.new
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: stdout
      )
      # When the trigger is run
      trigger.run
      # Then stdout should suggest creating the three scripts
      assert_match(/lint\.sh.*build\.sh.*fast\.sh.*slow\.sh/m, stdout.string,
        "Should suggest creating the four hook scripts")
    end
  end
end

class TestTriggerBackgroundWiring < Minitest::Test
  include FunCiTestProject

  def test_should_call_fail_run_when_slow_suite_fails
    # Given a project where build and fast pass but slow fails
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      recorder = FakeRecorder.new
      fake_runner = ->(cmd) {
        if cmd.include?("slow.sh")
          ["slow test failed", FakeStatus.new(false, 1)]
        else
          ["", FakeStatus.new(true, 0)]
        end
      }
      launcher = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
        FunCi::BackgroundWrapper.new(
          recorder: recorder, job_id: job_id, executor: executor
        ).run
      }
      trigger = FunCi::Trigger.new(
        project_root: dir,
        commit_hash: "abc1234",
        branch: "main",
        stdout: StringIO.new,
        command_runner: fake_runner,
        commit_validator: ->(_h) { true },
        recorder: recorder,
        background_launcher: launcher
      )
      # When the trigger is run
      trigger.run
      # Then fail_run should be called (not complete_run)
      # because the slow suite failed
      assert recorder.calls.any? { |c| c[0] == :fail_run },
        "Should call fail_run when slow suite fails"
      refute recorder.calls.any? { |c| c[0] == :complete_run },
        "Should NOT call complete_run when slow suite fails"
    end
  end
end
