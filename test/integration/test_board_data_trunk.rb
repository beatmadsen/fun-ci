# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trunk_kit"
require "fun_ci/console/board_data"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/trunk_checks"

# A branch's row carries the branch's standing against the trunk, which its
# earlier runs' checks can decide (TrunkMarks decides which).
class TestBoardDataTrunk < Minitest::Test
  include DatabaseTestSetup
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10)

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_keep_a_branch_s_conflict_on_its_row_while_its_newest_run_is_checked
    check(begin_run("aaa"), MERGE.conflicts(["a.rb"], ahead: 1, behind: 1))
    begin_run("bbb")

    assert_equal "conflicts", FunCi::Console::BoardData.new(@db).runs.first[:trunk][:branch_state]
  end

  private

  def begin_run(sha)
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: sha, branch: "main", project_path: "/project")
    sha
  end

  def check(sha, merge)
    FunCi::Persistence::TrunkChecks.new(@db, "/project").record(trunk_check(sha, merge, seen_at: NOW), checked_at: NOW)
  end
end
