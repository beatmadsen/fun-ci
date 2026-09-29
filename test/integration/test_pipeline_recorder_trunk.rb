# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trunk_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/trunk_checks"
require "fun_ci/persistence/active_runs"

# A run's check against the trunk, recorded under the run's project, by the
# recorder the run holds once its stages are done.
class TestDbRecorderTrunk < Minitest::Test
  include DatabaseTestSetup
  include TrunkKit

  CLEAN = FunCi::Trunk::Merge.clean(ahead: 1, behind: 2)

  def setup = setup_test_db
  def teardown = teardown_test_db

  def recorder_of_run
    recorder = FunCi::Persistence::DbRecorder.new(@db)
    recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project")
    recorder
  end

  def test_should_record_the_check_under_the_run_s_project
    run_id = FunCi::Persistence::DbRecorder.new(@db).create_run(commit_hash: "abc1234", branch: "main",
                                                                project_path: "/project")
    FunCi::Persistence::DbRecorder.new(@db, pipeline_run_id: run_id)
                                  .trunk_checked(trunk_check("abc1234", CLEAN, seen_at: Time.now))

    assert_equal CLEAN, FunCi::Persistence::TrunkChecks.new(@db, "/project").latest("abc1234").merge
  end

  def test_should_keep_how_the_run_s_fetch_went_under_the_run_s_project
    recorder = recorder_of_run
    recorder.trunk_fetched(FunCi::Trunk::Fetched.new(error: "fatal: no remote"), nil)

    assert_equal "fatal: no remote", FunCi::Persistence::TrunkFetches.new(@db, "/project").last.error
  end

  def test_should_count_checks_against_the_tip_just_fetched_as_seen_now
    recorder = recorder_of_run
    recorder.trunk_checked(trunk_check("abc1234", CLEAN, seen_at: Time.utc(2026, 1, 1)))
    recorder.trunk_fetched(FunCi::Trunk::Fetched.new(error: nil), trunk_tip(seen_at: Time.now))

    assert_in_delta Time.now, FunCi::Persistence::TrunkChecks.new(@db, "/project").latest("abc1234").tip.seen_at, 60
  end

  def test_should_not_count_checks_as_seen_again_when_the_fetch_failed
    recorder = recorder_of_run
    recorder.trunk_checked(trunk_check("abc1234", CLEAN, seen_at: Time.utc(2026, 1, 1)))
    recorder.trunk_fetched(FunCi::Trunk::Fetched.new(error: "fatal: no remote"), trunk_tip(seen_at: Time.now))

    assert_equal Time.utc(2026, 1, 1),
                 FunCi::Persistence::TrunkChecks.new(@db, "/project").latest("abc1234").tip.seen_at
  end

  def test_should_know_no_last_fetch_without_a_database
    assert_nil FunCi::Persistence::TrunkRecording::NoFetches.new.last
  end

  def test_should_claim_fetches_for_the_run_s_project
    recorder_of_run.trunk_fetches.claim(now: Time.now, interval: 300)

    refute FunCi::Persistence::TrunkFetches.new(@db, "/project").claim(now: Time.now, interval: 300)
  end

  def test_should_note_when_the_run_began_its_check
    recorder = recorder_of_run
    recorder.trunk_check_started

    refute_nil FunCi::Persistence::PipelineRun.find(@db, recorder.pipeline_run_id)[:trunk_started_at]
  end

  def test_should_keep_the_fetch_s_process_group_for_a_cancel
    recorder = recorder_of_run
    recorder.trunk_fetch_process(4242)

    assert_includes FunCi::Persistence::ActiveRuns.with_id(@db, recorder.pipeline_run_id).first.stage_groups, 4242
  end

  def test_should_record_a_check_without_a_tip
    run_id = FunCi::Persistence::DbRecorder.new(@db).create_run(commit_hash: "abc1234", branch: "main",
                                                                project_path: "/project")
    unknown = FunCi::Trunk::Check.new(commit: "abc1234", tip: nil, merge: FunCi::Trunk::Merge.unknown("no trunk"))
    FunCi::Persistence::DbRecorder.new(@db, pipeline_run_id: run_id).trunk_checked(unknown)

    assert_equal unknown, FunCi::Persistence::TrunkChecks.new(@db, "/project").latest("abc1234")
  end
end
