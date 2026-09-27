# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# A secret in a failed stage's output is masked before it is kept
# (acceptance-tests.md, AT-10.5).
class TestAgentWhyMasksSecrets < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  SECRET = "s3cr3t-value-123"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: fast_suite_printing_its_token,
                                      environment: { "DEPLOY_TOKEN" => SECRET, "HOME" => "/home/dev" })
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_show_the_variable_s_name_where_its_value_was
    @agent.why

    assert_includes @agent.stdout, "  deploying with [masked:DEPLOY_TOKEN]\n"
  end

  def test_should_keep_the_value_nowhere_in_the_database
    refute_includes @pipeline.workspace.database_bytes, SECRET
  end

  private

  def fast_suite_printing_its_token
    lambda do |cmd, env|
      next ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

      ["deploying with #{env.fetch("DEPLOY_TOKEN")}\n", FakeStatus.new(false, 1)]
    end
  end
end
