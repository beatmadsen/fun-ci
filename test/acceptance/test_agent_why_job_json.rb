# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# `fun-ci why --job NAME --json`: a job's latest run as one document
# (acceptance-tests.md, AT-13.21).
class TestAgentWhyJobJson < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  FAILED = JobRecording::JobRunFacts.new(status: "failed", output: "Survived: 3\n", exit_status: 1)

  def setup
    @agent = AgentClient.open
    @agent.add_job("soak", "weekly")
  end

  def teardown = @agent.close

  def test_should_give_the_job_its_evidence_and_ending_as_one_document_with_json
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--json")

    expected = { "name" => "soak", "cadence" => "weekly", "state" => "failed", "exit_status" => 1, "budget" => 86_400 }

    assert_equal expected, JSON.parse(@agent.stdout).slice(*expected.keys)
  end

  def test_should_give_a_job_that_never_ran_no_commit_as_json
    @agent.why("--job", "soak", "--json")

    assert_nil JSON.parse(@agent.stdout)["commit"]
  end

  def test_should_say_how_many_bytes_of_raw_output_are_kept_as_json
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--json")

    assert_equal 12, JSON.parse(@agent.stdout).dig("raw_output", "bytes")
  end

  def test_should_carry_no_evidence_for_a_job_that_passed_as_json
    @agent.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "completed", exit_status: 0))
    @agent.why("--job", "soak", "--json")

    assert_nil JSON.parse(@agent.stdout)["evidence"]
  end

  def test_should_give_no_reason_for_no_evidence_when_there_is_evidence_as_json
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--json")

    assert_nil JSON.parse(@agent.stdout)["no_evidence"]
  end

  def test_should_carry_the_evidence_in_the_json_document
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--json")

    assert_equal ["Survived: 3"], JSON.parse(@agent.stdout).dig("evidence", "excerpts", 0, "lines")
  end
end
