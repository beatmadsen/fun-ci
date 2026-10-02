# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/job_order"

# The order of the job section's rows (design.md, The console): failed, ran
# out of time, running, due, passed; the board's projects in its order among
# equals, then by name (acceptance-tests.md, AT-13.14).
class TestJobOrder < Minitest::Test
  Row = Data.define(:name, :state, :project)

  def test_should_put_a_lost_job_with_the_failed_ones
    assert_equal %w[b a], names([row("a", "over_budget"), row("b", "lost")])
  end

  def test_should_put_a_cancelled_job_with_the_due_ones_before_a_passed_one
    assert_equal %w[b a], names([row("a", "passed"), row("b", "cancelled")])
  end

  def test_should_put_a_failed_job_before_one_that_ran_out_of_time
    assert_equal %w[b a], names([row("a", "over_budget"), row("b", "failed")])
  end

  def test_should_put_a_job_that_ran_out_of_time_before_a_running_one
    assert_equal %w[b a], names([row("a", "running"), row("b", "over_budget")])
  end

  def test_should_put_a_running_job_before_a_due_one
    assert_equal %w[b a], names([row("a", "due"), row("b", "running")])
  end

  # Under way, then about to be (Jobs::Schedule).
  def test_should_put_a_running_job_before_one_waiting_its_turn
    assert_equal %w[b a], names([row("a", "scheduled"), row("b", "running")])
  end

  def test_should_put_a_job_waiting_its_turn_before_a_due_one
    assert_equal %w[b a], names([row("a", "due"), row("b", "scheduled")])
  end

  def test_should_put_a_due_job_before_a_passed_one
    assert_equal %w[b a], names([row("a", "passed"), row("b", "due")])
  end

  def test_should_put_the_jobs_of_the_board_s_first_project_first_among_equals
    assert_equal %w[b a], names([row("a", "passed", "/second"), row("b", "passed", "/first")])
  end

  def test_should_put_a_project_s_jobs_in_the_order_of_their_names_among_equals
    assert_equal %w[a b], names([row("b", "passed"), row("a", "passed")])
  end

  def test_should_put_a_job_of_a_status_it_does_not_know_last
    assert_equal %w[b a], names([row("a", "paused"), row("b", "passed")])
  end

  private

  def names(rows) = FunCi::Console::JobOrder.of(rows, projects: %w[/first /second]).map(&:name)
  def row(name, state, project = "/first") = Row.new(name: name, state: state, project: project)
end
