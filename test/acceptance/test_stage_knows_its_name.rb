# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Every stage script knows its stage (acceptance-tests.md, AT-10.7), so a
# project can send each stage's logs to a file of its own.
class TestStageKnowsItsName < Minitest::Test
  def setup
    @seen = {}
    @client = TriggerCliClient.open(command_runner: method(:record_stage_name), background_launcher: SYNC_LAUNCHER)
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end

  def teardown = @client.close

  def test_should_name_each_stage_to_its_own_script
    assert_equal({ "lint.sh" => "lint", "build.sh" => "build", "fast.sh" => "fast", "slow.sh" => "slow" }, @seen)
  end

  private

  def record_stage_name(cmd, env)
    @seen[File.basename(cmd.split.first)] = env["FUN_CI_STAGE"]
    ["", FakeStatus.new(true, 0)]
  end
end
