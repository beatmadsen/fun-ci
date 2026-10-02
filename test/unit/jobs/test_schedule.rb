# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/jobs/schedule"
require "fun_ci/jobs/job"

# When each of the jobs a commit starts begins (design.md, Daily and weekly
# jobs): one at a time, `spacing` apart, after any job of the project that
# is still to start or running, so their work is spread over time rather
# than taking every core at once.
class TestSchedule < Minitest::Test
  NOW = Time.utc(2026, 10, 2, 12)
  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/p/.fun-ci/weekly/soak.sh")
  FUZZ = FunCi::Jobs::Job.new(name: "fuzz", cadence: "daily", script: "/p/.fun-ci/daily/fuzz.sh")
  ASAN = FunCi::Jobs::Job.new(name: "asan", cadence: "daily", script: "/p/.fun-ci/daily/asan.sh")

  def test_should_start_the_first_job_now
    assert_equal NOW, starts([FUZZ, SOAK]).first.last
  end

  def test_should_start_each_next_job_a_spacing_after_the_one_before
    assert_equal [NOW, NOW + 600, NOW + 1200], starts([ASAN, FUZZ, SOAK]).map(&:last)
  end

  def test_should_start_the_first_job_a_spacing_after_the_latest_start_of_one_already_begun_or_waiting
    assert_equal NOW + 420, starts([FUZZ], begun: [NOW - 900, NOW - 180]).first.last
  end

  def test_should_start_the_first_job_now_when_the_latest_one_begun_started_a_spacing_ago_or_more
    assert_equal NOW, starts([FUZZ], begun: [NOW - 600]).first.last
  end

  def test_should_start_every_job_now_when_the_spacing_is_none
    assert_equal [NOW, NOW], starts([FUZZ, SOAK], spacing: 0).map(&:last)
  end

  def test_should_keep_each_job_with_its_start
    assert_equal [FUZZ, SOAK], starts([FUZZ, SOAK]).map(&:first)
  end

  private

  def starts(jobs, begun: [], spacing: 600) = FunCi::Jobs::Schedule.new(spacing, begun, now: NOW).starts(jobs)
end
