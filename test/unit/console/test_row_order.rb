# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/row_order"

# The order of the console's rows (design.md, The console): a project's
# branches together, the project that most needs you first, and within it
# the branch that most needs you first.
class TestRowOrder < Minitest::Test
  def test_should_put_a_failed_branch_before_a_passed_one_run_later
    rows = [row(1, "completed"), row(2, "failed")]

    assert_equal [2, 1], ids(rows)
  end

  def test_should_put_a_timed_out_branch_after_a_failed_one
    rows = [row(1, "timed_out"), row(2, "failed")]

    assert_equal [2, 1], ids(rows)
  end

  def test_should_put_a_branch_that_conflicts_with_the_trunk_before_a_running_one
    rows = [row(1, "running"), row(2, "completed", trunk: { branch_state: "conflicts", trunk: "main" })]

    assert_equal [2, 1], ids(rows)
  end

  def test_should_put_a_running_branch_before_a_scheduled_one
    rows = [row(1, "scheduled"), row(2, "running")]

    assert_equal [2, 1], ids(rows)
  end

  def test_should_put_a_scheduled_branch_before_a_passed_one
    rows = [row(1, "completed"), row(2, "scheduled")]

    assert_equal [2, 1], ids(rows)
  end

  def test_should_put_a_cancelled_branch_last
    rows = [row(1, "cancelled"), row(2, "completed")]

    assert_equal [2, 1], ids(rows)
  end

  # Forty rows, as many as it takes Ruby's sort to reorder rows it finds equal.
  def test_should_keep_equally_urgent_branches_newest_first
    rows = (1..40).map { |id| row(id, (id % 3).zero? ? "failed" : "completed") }

    assert_equal [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39,
                  1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 29, 31, 32, 34, 35, 37, 38, 40],
                 ids(rows)
  end

  def test_should_keep_a_project_s_branches_together
    rows = [row(1, "completed", project: "/a"), row(2, "completed", project: "/b"), row(3, "completed", project: "/a")]

    assert_equal [1, 3, 2], ids(rows)
  end

  def test_should_put_first_the_project_whose_branch_most_needs_you
    rows = [row(3, "running", project: "/a"), row(2, "completed", project: "/b"), row(1, "failed", project: "/b")]

    assert_equal [1, 2, 3], ids(rows)
  end

  private

  def row(id, status, project: "/a", trunk: nil) = { id: id, status: status, project_path: project, trunk: trunk }
  def ids(rows) = FunCi::Console::RowOrder.of(rows).map { |row| row[:id] }
end
