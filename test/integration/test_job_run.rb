# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/job_run_kit"

# One run of a job, in the process that runs it (acceptance-tests.md, AT-13.5, AT-13.6, AT-13.8, AT-13.9).
class TestJobRun < Minitest::Test
  include JobRunKit

  SURVIVORS = <<~YAML
    evidence:
      jobs:
        mutation:
          - use: grep
            title: survivors
            patterns: ["^Survived"]
  YAML

  def test_should_run_the_project_s_script_with_the_commit_when_the_commit_has_no_copy
    commands = []
    run_job(runner: ->(cmd) { (commands << cmd) && PASSED })

    assert_equal ["#{File.join(project, ".fun-ci", "daily", "mutation.sh")} #{SHA}"], commands
  end

  def test_should_record_a_job_whose_script_exits_zero_passed
    run_job(runner: ->(_cmd) { PASSED })

    assert_equal "completed", latest[:status]
  end

  def test_should_record_a_job_whose_script_fails_failed
    run_job(runner: ->(_cmd) { ["boom\n", FakeStatus.new(false, 1)] })

    assert_equal "failed", latest[:status]
  end

  def test_should_record_a_job_past_its_budget_out_of_time
    run_job(runner: ->(_cmd) { raise Timeout::Error })

    assert_equal "timed_out", latest[:status]
  end

  def test_should_check_out_the_commit_in_the_job_s_own_worktree
    run_job

    assert_equal [[File.join(locks_root, "mutation"), SHA]], @worktrees.checked_out
  end

  def test_should_tell_the_script_which_job_it_is
    seen = nil
    run_job(runner: ->(_cmd, env) { (seen = env) && PASSED })

    assert_equal "mutation", seen["FUN_CI_JOB"]
  end

  def test_should_run_the_commit_s_own_copy_of_the_script_when_it_has_one
    committed = commit_a_copy_of_the_script
    commands = []
    run_job(runner: ->(cmd) { (commands << cmd) && PASSED })

    assert_equal ["#{committed} #{SHA}"], commands
  end

  def test_should_keep_the_evidence_the_job_s_own_entries_pick_out
    commit_a_config(SURVIVORS)
    run_job(runner: ->(_cmd) { ["Survived: 3\n", FakeStatus.new(false, 1)] })

    assert_includes latest[:evidence], "survivors"
  end

  def test_should_record_the_process_that_runs_the_job
    run_job

    assert_equal Process.pid, latest[:pid]
  end

  def test_should_run_nothing_while_another_process_holds_the_job_s_lock
    commands = []
    holding_the_lock { run_job(runner: ->(cmd) { (commands << cmd) && PASSED }) }

    assert_empty commands
  end

  def test_should_run_nothing_when_the_job_is_not_due
    run_job
    commands = []
    run_job(runner: ->(cmd) { (commands << cmd) && PASSED })

    assert_empty commands
  end

  def test_should_record_failed_a_run_left_running_by_a_process_that_died
    first = claim_a_run_nobody_runs
    run_job

    assert_equal "failed", status_of(first)
  end

  def test_should_say_why_a_run_left_by_a_process_that_died_has_no_result
    first = claim_a_run_nobody_runs
    run_job

    assert_includes evidence_of(first), "its process stopped before it said how the run ended"
  end

  def test_should_record_failed_a_job_whose_worktree_could_not_be_checked_out
    @worktrees.fail_with("git checkout: no such commit")
    run_job

    assert_equal "failed", latest[:status]
  end

  def test_should_record_failed_a_job_that_could_not_start_for_any_reason
    @worktrees.fail_with("the disk is full", error: Errno::ENOSPC)
    run_job

    assert_equal "failed", latest[:status]
  end

  def test_should_keep_why_the_job_s_worktree_could_not_be_checked_out
    @worktrees.fail_with("git checkout: no such commit")
    run_job

    assert_includes latest[:evidence], "git checkout: no such commit"
  end

  def test_should_let_go_of_the_job_s_lock_once_it_has_run
    run_job

    refute FunCi::Pipeline::SlotLock.held?(File.join(locks_root, "mutation.lock"))
  end
end
