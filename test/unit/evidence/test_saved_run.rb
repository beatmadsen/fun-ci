# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/saved_run"

# What `fun-ci extract` stands in for a failed run's stage directory with.
class TestSavedRun < Minitest::Test
  def test_should_point_a_command_at_the_reports_it_was_given
    assert_equal "/project/reports", FunCi::Evidence::SavedRun.new("/project/reports", "/scratch").reports_path
  end

  def test_should_point_a_command_into_scratch_when_given_no_reports
    assert_equal "/scratch/reports", FunCi::Evidence::SavedRun.new(nil, "/scratch").reports_path
  end
end
