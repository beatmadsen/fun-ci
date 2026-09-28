# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/endless_coverage"

# The mutation lane's coverage, with the calls of one-line methods counted on
# their line, which Ruby's line coverage leaves at the one count of the def.
class TestEndlessCoverage < Minitest::Test
  FILE = "/lib/x.rb"

  def test_should_count_the_calls_of_a_one_line_method_on_its_line
    folded = fold(lines: [1, 1, nil], methods: { [Object, :a, 2, 2, 2, 20] => 3 })

    assert_equal [1, 4, nil], folded[:lines]
  end

  def test_should_leave_the_lines_of_a_method_over_several_lines_as_they_are
    folded = fold(lines: [1, 0, nil], methods: { [Object, :b, 1, 2, 3, 5] => 3 })

    assert_equal [1, 0, nil], folded[:lines]
  end

  def test_should_leave_a_one_line_method_never_called_uncovered
    folded = fold(lines: [1, 1], methods: { [Object, :a, 2, 2, 2, 20] => 0 })

    assert_equal [1, 1], folded[:lines]
  end

  def test_should_leave_lines_without_method_counts_as_they_are
    assert_equal({ FILE => [1, 0] }, EndlessCoverage.fold({ FILE => [1, 0] }))
  end

  private

  def fold(data) = EndlessCoverage.fold({ FILE => data }).fetch(FILE)
end
