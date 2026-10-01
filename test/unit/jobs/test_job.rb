# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/jobs/job"

# A job's period, budget and the name evidence knows it by (acceptance-tests.md, AT-13.3, AT-13.9, AT-13.10).
class TestJob < Minitest::Test
  def test_should_come_round_again_a_day_after_a_daily_run
    assert_equal 86_400, job("daily").period
  end

  def test_should_come_round_again_a_week_after_a_weekly_run
    assert_equal 604_800, job("weekly").period
  end

  def test_should_give_every_job_a_day_to_run
    assert_equal 86_400, FunCi::Jobs::Job::BUDGET
  end

  def test_should_be_known_to_evidence_under_jobs
    assert_equal "jobs/soak", job("weekly").stage
  end

  def test_should_read_the_job_a_stage_name_names
    assert_equal "soak", FunCi::Jobs::Job.named_by(job("weekly").stage)
  end

  def test_should_read_no_job_from_a_pipeline_stage_s_name
    assert_nil FunCi::Jobs::Job.named_by("lint")
  end

  private

  def job(cadence) = FunCi::Jobs::Job.new(name: "soak", cadence: cadence, script: "/p/.fun-ci/#{cadence}/soak.sh")
end
