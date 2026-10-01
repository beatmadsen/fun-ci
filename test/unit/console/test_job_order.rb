# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/job_order"

# The order of the job section's rows (design.md, The console): failed, ran
# out of time, running, due, passed; the board's projects in its order among
# equals, then by name (acceptance-tests.md, AT-13.14).
class TestJobOrder < Minitest::Test
  def test_should_put_a_failed_job_before_one_that_ran_out_of_time
    assert_equal %w[b a], names([row("a", "timed_out"), row("b", "failed")])
  end

  def test_should_put_a_job_that_ran_out_of_time_before_a_running_one
    assert_equal %w[b a], names([row("a", "running"), row("b", "timed_out")])
  end

  def test_should_put_a_running_job_before_a_due_one
    assert_equal %w[b a], names([row("a", "due"), row("b", "running")])
  end

  def test_should_put_a_due_job_before_a_passed_one
    assert_equal %w[b a], names([row("a", "completed"), row("b", "due")])
  end

  def test_should_put_the_jobs_of_the_board_s_first_project_first_among_equals
    assert_equal %w[b a], names([row("a", "completed", "/second"), row("b", "completed", "/first")])
  end

  def test_should_put_a_project_s_jobs_in_the_order_of_their_names_among_equals
    assert_equal %w[a b], names([row("b", "completed"), row("a", "completed")])
  end

  def test_should_put_a_job_of_a_status_it_does_not_know_last
    assert_equal %w[b a], names([row("a", "paused"), row("b", "completed")])
  end

  private

  def names(rows) = FunCi::Console::JobOrder.of(rows, projects: %w[/first /second]).map { |job| job[:name] }
  def row(name, status, project = "/first") = { name: name, status: status, project: project }
end
