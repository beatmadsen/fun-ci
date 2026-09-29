# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "../support/fake_trunk"
require "fun_ci/persistence/trunk_checks"

# Each run checks its commit against the trunk (docs/trunk-conflicts.md, AT-11.21, AT-11.22).
class TestTriggerTrunkCheck < Minitest::Test
  CONFLICTS = FunCi::Trunk::Merge.conflicts(["lib/cart.rb"], ahead: 3, behind: 4)

  def teardown = @client&.close

  def test_should_record_how_the_commit_stands_against_the_trunk
    trigger(INSTANT_SUCCESS_RUNNER)

    assert_equal CONFLICTS, check.merge
  end

  def test_should_record_the_check_when_lint_fails
    trigger(->(cmd) { cmd.include?("lint.sh") ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] })

    assert_equal CONFLICTS, check.merge
  end

  def test_should_note_when_the_run_began_its_check
    trigger(INSTANT_SUCCESS_RUNNER)

    refute_nil @client.pipeline_runs_for(commit_hash: "abc1234").first[:trunk_started_at]
  end

  private

  def trigger(runner)
    @client = TriggerCliClient.open(command_runner: runner, trunk: FakeTrunk.new(CONFLICTS))
    @client.trigger(commit_hash: "abc1234", branch: "feat/cart")
  end

  def check = FunCi::Persistence::TrunkChecks.new(@client.db, @client.project_dir).latest("abc1234")
end
