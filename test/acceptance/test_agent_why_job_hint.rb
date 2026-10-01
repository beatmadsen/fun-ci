# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# `fun-ci why --job` says how to keep more of a job's evidence when only its
# output's last lines were kept, and only then (acceptance-tests.md, AT-13.21).
class TestAgentWhyJobHint < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  FAILED = JobRecording::JobRunFacts.new(status: "failed", output: "Survived: 3\n", exit_status: 1)

  def setup
    @agent = AgentClient.open
    @agent.add_job("soak", "weekly")
  end

  def teardown = @agent.close

  def test_should_say_how_to_keep_more_when_only_the_last_lines_were_kept
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.why("--job", "soak")

    assert_includes @agent.stdout, "extractors under `evidence: jobs: soak:` in .fun-ci/config keep more."
  end

  def test_should_not_say_how_to_keep_more_when_nothing_was_kept
    @agent.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "failed", exit_status: 1))
    @agent.why("--job", "soak")

    refute_includes @agent.stdout, "keep more"
  end

  def test_should_not_say_how_to_keep_more_when_an_extractor_kept_more
    @agent.record_job_run("soak", SHA, FAILED.with(extractor: "grep"))
    @agent.why("--job", "soak")

    refute_includes @agent.stdout, "keep more"
  end
end
