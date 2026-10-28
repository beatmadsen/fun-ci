# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# In 2.4.0 and earlier, a slow stage whose process died was kept failed with
# no finish order, which a verdict needs to tell which of a run's failures
# came first. Migrating numbers each such stage.
class TestFailuresKeptUnnumbered < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
  end

  def teardown
    teardown_test_db
  end

  def test_should_number_a_failed_stage_kept_without_a_finish_order_after_the_rest_of_its_run
    migrated([["fast", "timed_out", 1, "10:00"], ["slow", "failed", nil, "10:05"]])

    assert_equal [[1], [2]], finish_orders
  end

  def test_should_number_failed_stages_kept_without_a_finish_order_in_the_order_they_ended
    migrated([["fast", "failed", nil, "10:05"], ["slow", "timed_out", nil, "10:01"]])

    assert_equal [[2], [1]], finish_orders
  end

  # A cancelled run's stages are kept unnumbered, so a run's snapshots leave them out.
  def test_should_leave_a_cancelled_stage_kept_without_a_finish_order_unnumbered
    migrated([["slow", "cancelled", nil, "10:05"]])

    assert_equal [[nil]], finish_orders
  end

  private

  # The run kept with these [stage, status, finish order, time it ended], then migrated.
  def migrated(stages)
    stages.each do |stage, status, order, ended|
      @db.execute("INSERT INTO stage_jobs (pipeline_run_id, stage, status, finished_order, completed_at) " \
                  "VALUES (?, ?, ?, ?, ?)", [@run_id, stage, status, order, "2026-10-28T#{ended}:00.000Z"])
    end
    FunCi::Persistence::Database.migrate!(@db)
  end

  def finish_orders = @db.execute("SELECT finished_order FROM stage_jobs ORDER BY id")
end
