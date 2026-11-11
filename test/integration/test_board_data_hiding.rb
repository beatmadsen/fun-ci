# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/board_data"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/jobs/job"

# What the console does to keep a job or a branch out of view, and to show it
# again (acceptance-tests.md, AT-13.29 to AT-13.31, AT-13.33). When a snooze ends is
# Persistence::JobVisibility's (test_job_visibility.rb).
class TestBoardDataHiding < Minitest::Test
  include DatabaseTestSetup

  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/project/.fun-ci/weekly/soak.sh")

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    write_job(File.join(@project, ".fun-ci", "weekly", "soak.sh"))
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main", project_path: @project)
  end

  def teardown = teardown_test_db

  def test_should_hide_a_job_the_way_it_is_told_to
    board.hide_job(job_row, "ignored")

    assert_equal ["ignored"], board.jobs(board.runs).map(&:hidden)
  end

  # A run begun before the snooze doesn't end it: the snooze is from the clock's now, not the wall's.
  def test_should_snooze_a_job_from_now
    later = board(clock: -> { Time.now + 60 })
    FunCi::Persistence::JobRuns.new(@db, @project).claim(SOAK, commit: { sha: "abc1234", branch: "main" },
                                                               lock_file: "/soak.lock", now: Time.now + 30)
    later.hide_job(job_row, "snoozed")

    assert_equal ["snoozed"], later.jobs(later.runs).map(&:hidden)
  end

  def test_should_show_a_hidden_job_again
    board.hide_job(job_row, "ignored")

    board.show_job(job_row)

    assert_equal [nil], board.jobs(board.runs).map(&:hidden)
  end

  def test_should_hide_a_branch_the_way_it_is_told_to
    board.hide_run(board.runs.first, "ignored")

    assert_equal ["ignored"], branches_hidden
  end

  def test_should_leave_a_branch_no_one_hid_unmarked
    assert_equal [nil], branches_hidden
  end

  def test_should_show_a_hidden_branch_again
    board.hide_run(board.runs.first, "ignored")

    board.show_run(board.runs.first)

    assert_equal [nil], branches_hidden
  end

  # A hidden branch leaves its place on the page, 15 branches by default, to the next one.
  def test_should_hold_a_page_of_branches_in_view_beside_a_hidden_one
    twenty_more_branches
    board.hide_run(board.runs.first, "ignored")

    assert_equal 15, branches_hidden.count(nil)
  end

  # The 20 branches run most recently widen by those hidden, or hidden ones would leave the page short.
  def test_should_hold_a_page_of_branches_in_view_beside_six_hidden_ones
    twenty_more_branches
    hide_branches(6)

    assert_equal 15, branches_hidden.count(nil)
  end

  private

  def hide_branches(count) = board.runs.first(count).each { |run| board.hide_run(run, "ignored") }

  def twenty_more_branches
    (1..20).each { |n| FunCi::Persistence::PipelineRun.create(@db, commit_hash: "c#{n}", branch: "b#{n}", project_path: @project) }
  end

  def board(clock: -> { Time.now }) = FunCi::Console::BoardData.new(@db, clock: clock)
  def job_row = board.jobs(board.runs).first
  def branches_hidden = board.runs.map { |run| run[:hidden] }

  def write_job(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end
end
