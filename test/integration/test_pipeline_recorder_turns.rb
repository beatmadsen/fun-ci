# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"

# What a slow suite waiting its branch's turn reads and writes through its
# recorder (acceptance-tests.md, AT-9.19, AT-9.20).
class TestPipelineRecorderTurns < Minitest::Test
  include DbRecorderTestSetup

  RUN = FunCi::Persistence::PipelineRun

  def test_should_place_a_run_where_its_commit_first_arrived_on_the_branch
    first = RUN.create(@db, commit_hash: "abc1234", branch: "main", project_path: "/project")
    RUN.create(@db, commit_hash: "bcd2345", branch: "main", project_path: "/project")
    @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project")

    assert_equal first, @recorder.arrival_place
  end

  def test_should_place_a_commit_s_first_run_at_itself
    run_id = @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project")

    assert_equal run_id, @recorder.arrival_place
  end

  def test_should_let_a_slow_suite_start_whose_stage_could_not_be_recorded
    create_run

    assert @recorder.started_in_turn?(nil)
  end
end
