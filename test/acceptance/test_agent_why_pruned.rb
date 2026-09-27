# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A run whose evidence was pruned says so (acceptance-tests.md, AT-10.3):
# only a project's 50 newest runs keep what their failed stages left.
class TestAgentWhyPruned < Minitest::Test
  OLD = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: script_simulating_runner(failures: { "fast.sh" => {} }))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(OLD, "Add retry to fetch")
    @pipeline.trigger(commit_hash: OLD, branch: "main")
    50.times { |n| @pipeline.trigger(commit_hash: format("%040x", n), branch: "main") }
  end

  def teardown = @pipeline.close

  def test_should_say_the_evidence_is_no_longer_kept_and_why
    @agent.why(OLD)

    assert_equal "Its evidence is no longer kept: fun-ci keeps it for a project's 50 newest runs.",
                 @agent.stdout.lines[2].chomp
  end

  def test_should_exit_with_the_verdict
    assert_equal 1, @agent.why(OLD)
  end

  def test_should_tell_a_program_the_evidence_was_pruned
    @agent.why(OLD, "--json")

    assert_equal [nil, "pruned"], JSON.parse(@agent.stdout).values_at("evidence", "no_evidence")
  end
end
