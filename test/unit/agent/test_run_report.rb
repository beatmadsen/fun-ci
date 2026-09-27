# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/run_report"

class TestRunReport < Minitest::Test
  RUN = { id: 7, commit_hash: "3f9c2ab0c4d1", branch: "main", status: "running" }.freeze
  COMMIT = { subject: "Add retry", superseded_by: nil }.freeze

  def test_should_list_the_four_stages_in_pipeline_order
    assert_equal %w[lint build fast slow], report(job("build", "running"), job("lint", "completed")).stages.map(&:name)
  end

  def test_should_call_a_stage_that_has_not_started_waiting
    assert_equal "waiting", report(job("lint", "running")).stages.last.state
  end

  def test_should_name_each_outcome_in_the_agent_s_words
    states = report(job("lint", "completed"), job("build", "timed_out"), job("fast", "failed"),
                    job("slow", "cancelled")).stages.map(&:state)

    assert_equal %w[passed over_budget failed cancelled], states
  end

  def test_should_give_a_finished_stage_s_duration_in_tenths_of_a_second
    assert_in_delta 3.8, report(job("lint", "completed", seconds: 3.84)).stages.first.seconds
  end

  def test_should_give_no_duration_while_a_stage_runs
    assert_nil report(job("lint", "running")).stages.first.seconds
  end

  def test_should_decide_the_verdict_for_the_level_needed
    assert_equal :passed, report(job("lint", "completed"), job("build", "completed"), need: "build").verdict
  end

  private

  def report(*jobs, need: "fast")
    FunCi::Agent::RunReport.build(run: RUN, jobs: jobs, need: need, commit: COMMIT)
  end

  def job(stage, status, seconds: nil)
    started = Time.utc(2026, 9, 27, 12)
    completed = seconds && (started + seconds).iso8601(3)
    { stage: stage, status: status, started_at: started.iso8601(3), completed_at: completed, finished_order: 1 }
  end
end
