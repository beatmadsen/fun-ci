# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/job_run_kit"
require "fun_ci/persistence/active_jobs"

# A job run given a later start (Jobs::Schedule, AT-13.28) holds the job's
# lock and waits its turn, kept scheduled, then runs as any run does; one
# cancelled while it waited never runs.
class TestJobRunScheduled < Minitest::Test
  include JobRunKit

  LATER = NOW + 600

  def test_should_wait_until_its_turn
    waits = []
    run_at(LATER, ->(seconds) { waits << seconds })

    assert_equal [600], waits
  end

  def test_should_not_wait_when_its_turn_is_now
    waits = []
    run_at(NOW, ->(seconds) { waits << seconds })

    assert_empty waits
  end

  def test_should_be_scheduled_while_it_waits
    seen = []
    run_at(LATER, ->(_) { seen << latest[:status] })

    assert_equal ["scheduled"], seen
  end

  # So that a cancel finds the process that waits, and stops it.
  def test_should_say_which_process_waits
    seen = []
    run_at(LATER, ->(_) { seen << latest[:pid] })

    assert_equal [Process.pid], seen
  end

  def test_should_run_the_script_once_its_turn_has_come
    commands = []
    run_at(LATER, ->(_) {}, runner: recording(commands))

    assert_equal 1, commands.size
  end

  def test_should_not_run_the_script_of_a_run_cancelled_while_it_waited
    commands = []
    run_at(LATER, ->(_) { FunCi::Persistence::ActiveJobs.cancelled(@db, latest[:id]) }, runner: recording(commands))

    assert_empty commands
  end

  private

  def run_at(at, wait, runner: ->(_cmd) { PASSED })
    seams = FunCi::Pipeline::Seams.new(command_runner: runner, stage_dir: -> { FakeStageDir.new }, environment: {})
    FunCi::Jobs::JobRun.new(job, FunCi::Pipeline::Commit.new(sha: SHA, branch: "main"), site(wait: wait), seams)
                       .start(at: at)
  end
end
