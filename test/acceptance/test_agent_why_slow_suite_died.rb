# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "fun_ci/persistence/active_runs"

# A slow suite whose process died left no output and no exit status; `why`
# says it stopped, so it reads apart from a failure of the code.
class TestAgentWhySlowSuiteDied < Minitest::Test
  SHA = "8d01539c4d1e2f3a4b5c6d7e8f901234567890ab"

  def setup
    @agent = AgentClient.open
    @agent.git.commit(SHA, "victim")
    run_id = @agent.record_run(SHA, stages: { "lint" => "completed", "build" => "completed", "fast" => "completed",
                                              "slow" => "running" })
    slow = FunCi::Persistence::StageJob.for_run(@agent.db, run_id).find { |job| job[:stage] == "slow" }
    FunCi::Persistence::ActiveRuns.slow_suite_died(@agent.db, slow[:id])
  end

  def teardown = @agent.close

  def test_should_say_the_slow_suite_s_process_stopped_before_it_ended
    @agent.why("slow", "--need", "all")

    assert_includes @agent.stdout, "its process stopped before it said how the stage ended"
  end
end
