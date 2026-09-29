# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trunk_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/trunk_checks"

# A run's check against the trunk, recorded under the run's project, by the
# recorder the run holds once its stages are done.
class TestDbRecorderTrunk < Minitest::Test
  include DatabaseTestSetup
  include TrunkKit

  CLEAN = FunCi::Trunk::Merge.clean(ahead: 1, behind: 2)

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_record_the_check_under_the_run_s_project
    run_id = FunCi::Persistence::DbRecorder.new(@db).create_run(commit_hash: "abc1234", branch: "main",
                                                                project_path: "/project")
    FunCi::Persistence::DbRecorder.new(@db, pipeline_run_id: run_id)
                                  .trunk_checked(trunk_check("abc1234", CLEAN, seen_at: Time.now))

    assert_equal CLEAN, FunCi::Persistence::TrunkChecks.new(@db, "/project").latest("abc1234").merge
  end

  def test_should_record_a_check_without_a_tip
    run_id = FunCi::Persistence::DbRecorder.new(@db).create_run(commit_hash: "abc1234", branch: "main",
                                                                project_path: "/project")
    unknown = FunCi::Trunk::Check.new(commit: "abc1234", tip: nil, merge: FunCi::Trunk::Merge.unknown("no trunk"))
    FunCi::Persistence::DbRecorder.new(@db, pipeline_run_id: run_id).trunk_checked(unknown)

    assert_equal unknown, FunCi::Persistence::TrunkChecks.new(@db, "/project").latest("abc1234")
  end
end
