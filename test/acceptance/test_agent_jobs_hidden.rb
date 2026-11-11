# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"
require "fun_ci/persistence/job_visibility"

# Hiding a job changes what the console shows and nothing else: an agent is
# told of a hidden job as of any other (acceptance-tests.md, AT-13.30).
class TestAgentJobsHidden < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  FAILED = JobRecording::JobRunFacts.new(status: "failed", exit_status: 1, ago: 3600, seconds: 2)

  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed", "slow" => "completed" }.freeze

  def setup
    @agent = AgentClient.open
    @agent.git.commit(SHA, "Add retry to fetch")
    @agent.record_run(SHA, stages: PASSED)
    @agent.add_job("soak", "weekly")
    @agent.record_job_run("soak", SHA, FAILED)
    FunCi::Persistence::JobVisibility.new(@agent.db).hide(@agent.job_project, "soak", "ignored", at: @agent.clock.now)
  end

  def teardown = @agent.close

  def test_should_list_a_job_the_console_ignores
    @agent.jobs

    assert_match(/\Asoak +weekly  FAIL/, @agent.stdout)
  end

  def test_should_name_a_job_the_console_ignores_that_failed_on_the_commit
    @agent.status

    assert_includes @agent.stdout, "  soak (weekly job) FAILED  fun-ci why --job soak\n"
  end
end
