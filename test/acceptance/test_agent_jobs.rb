# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci jobs` lists the project's daily and weekly jobs (acceptance-tests.md, AT-13.22).
class TestAgentJobs < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  FAILED = JobRecording::JobRunFacts.new(status: "failed", exit_status: 1, ago: 3600, seconds: 2)
  PASSED = JobRecording::JobRunFacts.new(status: "completed", exit_status: 0, ago: 7200, seconds: 42)

  def setup
    @agent = AgentClient.open
    @agent.add_job("soak", "weekly")
    @agent.add_job("mutation", "daily")
    @agent.add_job("lint-deep", "daily")
  end

  def teardown = @agent.close

  def test_should_give_a_job_its_cadence_state_time_commit_age_and_when_it_is_due_again
    @agent.record_job_run("soak", SHA, FAILED, branch: "wip/foo")
    @agent.jobs

    assert_equal "soak       weekly  FAIL     2.0s  wip/foo 9e0b1d4  1h ago  due in 7d", line_of("soak")
  end

  def test_should_say_a_passed_job_is_due_in_hours_rounded_up
    @agent.record_job_run("mutation", SHA, PASSED)
    @agent.jobs

    assert_match(/  ok      42\.0s  main 9e0b1d4  2h ago  due in 22h\z/, line_of("mutation"))
  end

  def test_should_say_a_job_that_never_ran_runs_on_the_next_commit
    @agent.jobs

    assert_equal "lint-deep  daily   due   never ran  runs on the next commit", line_of("lint-deep")
  end

  def test_should_list_the_jobs_by_name
    @agent.jobs

    assert_equal(%w[lint-deep mutation soak], @agent.stdout.lines.map { |line| line.split.first })
  end

  def test_should_end_with_the_why_command_of_each_job_that_failed
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.jobs

    assert_equal "fun-ci why --job soak", @agent.stdout.lines.last.chomp
  end

  def test_should_say_where_to_put_jobs_in_a_project_without_any
    other = AgentClient.open
    other.jobs

    assert_equal "fun-ci: this project has no daily or weekly jobs; put their scripts in .fun-ci/daily/ or weekly/\n",
                 other.stdout
  ensure
    other.close
  end

  def test_should_give_each_job_as_json
    @agent.record_job_run("soak", SHA, FAILED, branch: "wip/foo")
    @agent.jobs("--json")

    soak = JSON.parse(@agent.stdout)["jobs"].find { |job| job["name"] == "soak" }

    assert_equal({ "cadence" => "weekly", "state" => "failed", "commit" => { "sha" => SHA, "branch" => "wip/foo" },
                   "seconds" => 2.0 }, soak.slice("cadence", "state", "commit", "seconds"))
  end

  def test_should_give_when_a_job_is_due_again_as_json
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.jobs("--json")

    soak = JSON.parse(@agent.stdout)["jobs"].find { |job| job["name"] == "soak" }

    assert_equal (@agent.clock.now - 3600 + 604_800).utc.iso8601, soak["due_at"]
  end

  def test_should_look_for_jobs_whose_process_died_before_listing_them
    @agent.jobs

    assert_equal 1, @agent.pipeline.watched
  end

  def test_should_exit_zero
    assert_equal 0, @agent.jobs
  end

  private

  def line_of(name) = @agent.stdout.lines.find { |line| line.start_with?("#{name} ") }.chomp
end
