# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# `fun-ci why --job NAME` prints everything kept about a daily or weekly
# job's latest run (acceptance-tests.md, AT-13.21).
class TestAgentWhyJob < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  FAILED = JobRecording::JobRunFacts.new(status: "failed", output: "Survived: 3\n", exit_status: 1)

  def setup
    @agent = AgentClient.open
    @agent.add_job("soak", "weekly")
    @agent.add_job("mutation", "daily")
  end

  def teardown = @agent.close

  def test_should_name_the_job_how_often_it_runs_and_the_commit_it_tested
    @agent.record_job_run("soak", SHA, FAILED, branch: "wip/foo")
    @agent.why("--job", "soak")

    assert_equal "fun-ci: job soak (weekly) on wip/foo 9e0b1d4", @agent.stdout.lines.first.chomp
  end

  def test_should_say_how_the_job_ended_against_its_budget
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak")

    assert_equal "soak failed (exit 1) after 2.0s, budget 24h", @agent.stdout.lines[1].chomp
  end

  def test_should_print_the_evidence_kept
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak")

    assert_includes @agent.stdout, "  Survived: 3\n"
  end

  def test_should_name_the_command_for_the_whole_output
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak")

    assert_includes @agent.stdout, "The whole output: fun-ci why --job soak --raw\n"
  end

  def test_should_print_the_output_kept_with_raw
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--raw")

    assert_equal "Survived: 3\n", @agent.stdout
  end

  def test_should_exit_1_for_a_job_that_failed
    @agent.record_job_run("soak", SHA, FAILED)

    assert_equal 1, @agent.why("--job", "soak")
  end

  def test_should_exit_2_for_a_job_that_ran_over_budget
    @agent.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "timed_out", seconds: 86_400))

    assert_equal 2, @agent.why("--job", "soak")
  end

  def test_should_exit_0_for_a_job_that_passed
    @agent.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "completed", exit_status: 0))

    assert_equal 0, @agent.why("--job", "soak")
  end

  def test_should_exit_3_for_a_job_still_running
    @agent.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "running"))

    assert_equal 3, @agent.why("--job", "soak")
  end

  def test_should_exit_5_for_a_job_that_never_ran
    assert_equal 5, @agent.why("--job", "soak")
  end

  def test_should_say_a_job_that_never_ran_has_nothing_to_explain
    @agent.why("--job", "soak")

    assert_equal "fun-ci: job soak (weekly) has not run yet; it runs on the next commit.\n", @agent.stdout
  end

  def test_should_refuse_a_name_that_is_no_job_naming_the_jobs
    @agent.why("--job", "nosuch")

    assert_equal "fun-ci why: no job 'nosuch' in this project: its jobs are mutation, soak\n", @agent.stdout
  end

  def test_should_exit_with_a_usage_error_for_a_name_that_is_no_job
    assert_equal 64, @agent.why("--job", "nosuch")
  end

  def test_should_give_the_job_its_evidence_and_ending_as_one_document_with_json
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--json")

    expected = { "name" => "soak", "cadence" => "weekly", "state" => "failed", "exit_status" => 1, "budget" => 86_400 }

    assert_equal expected, JSON.parse(@agent.stdout).slice(*expected.keys)
  end

  def test_should_carry_the_evidence_in_the_json_document
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak", "--json")

    assert_equal ["Survived: 3"], JSON.parse(@agent.stdout).dig("evidence", "excerpts", 0, "lines")
  end
end
