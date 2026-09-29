# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/cancelled_folding"

# Runs of one branch cancelled one after another, as a rebase or a burst of
# commits leaves them, show as one row: the newest of them, saying how many
# it stands for (design.md, The console).
class TestCancelledFolding < Minitest::Test
  def run_row(id, status: "cancelled", branch: "detached", project: "/src/app")
    { id: id, status: status, branch: branch, project_path: project }
  end

  def folded(runs) = FunCi::Console::CancelledFolding.fold(runs)
  def ids(runs) = folded(runs).map { |run| run[:id] }

  def test_should_keep_the_newest_of_consecutive_cancelled_runs_of_a_branch
    assert_equal [3], ids([run_row(3), run_row(2), run_row(1)])
  end

  def test_should_say_how_many_runs_the_kept_one_stands_for
    assert_equal 3, folded([run_row(3), run_row(2), run_row(1)]).first[:folded]
  end

  def test_should_leave_a_lone_cancelled_run_as_it_is
    assert_equal [run_row(1)], folded([run_row(1)])
  end

  def test_should_not_fold_across_a_run_that_was_not_cancelled
    runs = [run_row(3), run_row(2, status: "completed"), run_row(1)]

    assert_equal [3, 2, 1], ids(runs)
  end

  def test_should_not_fold_cancelled_runs_of_different_branches
    assert_equal [2, 1], ids([run_row(2, branch: "main"), run_row(1)])
  end

  def test_should_not_fold_cancelled_runs_of_different_projects
    assert_equal [2, 1], ids([run_row(2, project: "/src/lib"), run_row(1)])
  end
end
