# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "../support/fake_trunk"
require_relative "../support/trunk_kit"
require "fun_ci/persistence/trunk_checks"

# A run that finds the trunk moved checks the other branches' newest runs
# against it too (docs/trunk-conflicts.md, AT-11.25).
class TestTriggerTrunkRecheck < Minitest::Test
  include TrunkKit

  CLEAN = MERGE.clean(ahead: 1, behind: 1)
  OLD_TIP = "0ld0000"

  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER, trunk: FakeTrunk.new(CLEAN))
    @other = FunCi::Persistence::PipelineRun.create(@client.db, commit_hash: "bbb2222", branch: "feat/other",
                                                                project_path: @client.project_dir)
  end

  def teardown = @client.close

  def test_should_check_another_branch_s_newest_run_against_the_new_trunk
    stale = trunk_check("bbb2222", MERGE.conflicts(["a.rb"], ahead: 1, behind: 1), seen_at: Time.now - 60, sha: OLD_TIP)
    checks.record(stale, checked_at: Time.now)
    @client.trigger(commit_hash: "abc1234", branch: "feat/cart")

    assert_equal TRUNK_SHA, checks.latest("bbb2222").tip.sha
  end

  def test_should_leave_a_branch_whose_newest_run_was_never_checked_alone
    @client.trigger(commit_hash: "abc1234", branch: "feat/cart")

    assert_nil checks.latest("bbb2222")
  end

  private

  def checks = FunCi::Persistence::TrunkChecks.new(@client.db, @client.project_dir)
end
