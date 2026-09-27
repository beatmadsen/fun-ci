# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"

# The recorder keeps how a stage exited and the budget it had, which
# `fun-ci why` reads back (acceptance-tests.md, AT-10.1).
class TestPipelineRecorderExit < Minitest::Test
  include DbRecorderTestSetup

  def test_should_keep_the_budget_a_stage_starts_with
    create_run

    assert_equal 10, job(@recorder.start_stage("fast", budget: 10))[:budget]
  end

  def test_should_keep_a_stage_s_exit_status
    create_run
    job_id = @recorder.start_stage("fast")
    @recorder.keep_exit(job_id, 3, nil)

    assert_equal 3, job(job_id)[:exit_status]
  end

  def test_should_keep_the_signal_that_ended_a_stage
    create_run
    job_id = @recorder.start_stage("fast")
    @recorder.keep_exit(job_id, nil, "KILL")

    assert_equal "KILL", job(job_id)[:signal]
  end
end
