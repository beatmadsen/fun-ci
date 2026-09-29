# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# When a run began checking its commit against the trunk (docs/trunk-conflicts.md, What it answers).
class TestPipelineRunTrunk < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_keep_when_the_run_began_its_trunk_check
    id = RUN.create(@db, commit_hash: "abc123", branch: "main")
    RUN.trunk_started(@db, id, Time.utc(2026, 9, 29, 10))

    assert_equal "2026-09-29T10:00:00Z", RUN.find(@db, id)[:trunk_started_at]
  end

  def test_should_say_nothing_of_a_trunk_check_for_a_run_that_began_none
    id = RUN.create(@db, commit_hash: "abc123", branch: "main")

    assert_nil RUN.find(@db, id)[:trunk_started_at]
  end
end
