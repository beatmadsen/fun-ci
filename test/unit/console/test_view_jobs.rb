# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/view"
require "fun_ci/console/key_handler"

# A page leaves room for the job section, and the cursor on a job shows the
# last page of runs above it (acceptance-tests.md, AT-13.15, AT-13.16).
class TestViewJobs < Minitest::Test
  RUNS = (1..6).map { |id| ConsoleFakes.run_row(id) }
  # Three, so a page's two lines for the section can't be told from one a job.
  JOBS = [ConsoleFakes.job_row("soak"), ConsoleFakes.job_row("mutation"), ConsoleFakes.job_row("audit")].freeze

  def setup
    @board_data = ConsoleFakes::BoardData.new(RUNS)
    @board_data.job_rows = JOBS
    @view = FunCi::Console::View.new(key_handler: FunCi::Console::KeyHandler.new(board_data: @board_data))
    @view.resize(24)
  end

  def test_should_fit_two_runs_fewer_beside_the_job_section
    assert_equal [1, 2, 3, 4], ids
  end

  def test_should_fit_as_many_runs_as_before_without_jobs
    assert_equal [1, 2, 3, 4, 5, 6], ids(jobs: [])
  end

  def test_should_show_the_last_page_of_runs_while_the_cursor_is_on_a_job
    press(8)

    assert_equal [3, 4, 5, 6], ids
  end

  def test_should_point_the_cursor_past_the_page_s_runs_into_the_jobs
    press(8)

    assert_equal 5, page[:cursor]
  end

  def test_should_say_no_runs_are_below_while_the_cursor_is_on_a_job
    press(8)

    refute page[:has_more]
  end

  # The renderer fits what it can of it; a page of none would read as no runs at all.
  def test_should_keep_one_run_on_a_page_the_job_section_leaves_no_room_on
    @view.resize(20)

    assert_equal [1], ids
  end

  # The jobs reorder as one finishes: the cursor stays on mutation, now the first job.
  def test_should_keep_the_cursor_on_its_job_when_the_jobs_reorder
    press(8)

    assert_equal 4, page(jobs: [JOBS[1], JOBS[0], JOBS[2]])[:cursor]
  end

  private

  def page(jobs: JOBS) = @view.page(RUNS, more: false, jobs: jobs)
  def ids(jobs: JOBS) = page(jobs: jobs)[:runs].map { |run| run[:id] }
  def press(times) = times.times { @view.press("j") }
end
