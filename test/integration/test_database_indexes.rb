# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# Where a commit arrived is looked up for every run the board and the
# canceller read; without an index each lookup scans every run kept, and runs
# are never deleted (Persistence::Arrival).
class TestDatabaseIndexes < Minitest::Test
  include DatabaseTestSetup

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_find_where_a_commit_arrived_through_an_index
    plan = @db.execute("EXPLAIN QUERY PLAN SELECT #{FunCi::Persistence::Arrival::FIRST_RUN} FROM pipeline_runs")

    assert_includes plan.map(&:last).join("\n"), "SEARCH arrived USING COVERING INDEX pipeline_runs_arrival"
  end
end
