# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci status` names the daily and weekly jobs whose latest run tested the
# commit, and leaves the verdict to the pipeline (acceptance-tests.md, AT-13.24).
class TestAgentStatusJobs < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  OTHER = "aaa1111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed", "slow" => "completed" }.freeze
  FAILED = JobRecording::JobRunFacts.new(status: "failed", exit_status: 1)

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add retry to fetch")
    @client.add_job("soak", "weekly")
    @client.add_job("mutation", "daily")
    @client.record_run(SHA, stages: PASSED)
  end

  def teardown = @client.close

  def test_should_name_a_job_that_failed_on_the_commit_with_its_why_command
    @client.record_job_run("soak", SHA, FAILED)
    @client.status

    assert_includes @client.stdout, "  soak (weekly job) FAILED  fun-ci why --job soak\n"
  end

  def test_should_name_a_job_still_running_on_the_commit
    @client.record_job_run("mutation", SHA, JobRecording::JobRunFacts.new(status: "running"))
    @client.status

    assert_includes @client.stdout, "  mutation (daily job) running\n"
  end

  def test_should_leave_out_a_job_that_tested_the_commit_before_its_latest_run_tested_another
    @client.record_job_run("mutation", SHA, JobRecording::JobRunFacts.new(status: "completed", ago: 90_000))
    @client.record_job_run("mutation", OTHER, JobRecording::JobRunFacts.new(status: "completed", ago: 600))
    @client.status

    refute_includes @client.stdout, "mutation"
  end

  # A failing job reaches an agent's usual loop, whichever commit it tested.
  def test_should_name_a_job_failing_on_another_commit_with_that_commit
    @client.record_job_run("soak", OTHER, FAILED)
    @client.status

    assert_includes @client.stdout, "  soak (weekly job) FAILED on aaa1111  fun-ci why --job soak\n"
  end

  def test_should_carry_jobs_failing_on_other_commits_as_json
    @client.record_job_run("soak", OTHER, FAILED)
    @client.status("--json")

    assert_equal([%w[soak failed]],
                 JSON.parse(@client.stdout)["failing_jobs"].map { |job| job.values_at("name", "state") })
  end

  def test_should_exit_with_the_pipeline_s_verdict_whatever_the_jobs
    @client.record_job_run("soak", SHA, FAILED)

    assert_equal 0, @client.status("--need", "all")
  end

  def test_should_carry_the_commit_s_jobs_as_json
    @client.record_job_run("soak", SHA, FAILED)
    @client.status("--json")

    assert_equal([%w[soak failed]], JSON.parse(@client.stdout)["jobs"].map { |job| job.values_at("name", "state") })
  end
end
