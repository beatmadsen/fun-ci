# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/statement_coverage"

# The mutation lane's coverage, counting each line a statement spans: Ruby's
# line coverage counts a statement on its first line only, and a one-line
# method's calls not at all.
class TestStatementCoverage < Minitest::Test
  FILE = "/lib/x.rb"

  def test_should_count_the_calls_of_a_one_line_method_on_its_line
    folded = fold(lines: [1, 1, nil], methods: { [Object, :a, 2, 2, 2, 20] => 3 })

    assert_equal [1, 4, nil], folded[:lines]
  end

  def test_should_count_a_statement_on_each_line_it_continues_onto
    folded = fold(lines: [0, 3, nil, nil, 3, nil], methods: { [Object, :b, 1, 2, 6, 5] => 3 })

    assert_equal [0, 3, 3, 3, 3, 3], folded[:lines]
  end

  def test_should_leave_the_lines_of_a_statement_never_run_uncounted
    folded = fold(lines: [0, 3, 0, nil, nil], methods: { [Object, :b, 1, 2, 5, 5] => 3 })

    assert_equal [0, 3, 0, 0, 0], folded[:lines]
  end

  # A clause starts a branch the statement before it may never take.
  def test_should_leave_a_clause_and_what_continues_it_uncounted
    source = ["def b(x)\n", "  case x\n", "  when 1 then :one\n", "  when 2,\n", "       3 then :more\n", "  end\n"]
    folded = fold({ lines: [0, 3, 3, nil, nil, nil], methods: { [Object, :b, 1, 2, 6, 5] => 3 } }, source)

    assert_equal [0, 3, 3, nil, nil, nil], folded[:lines]
  end

  def test_should_leave_lines_outside_every_method_as_they_are
    folded = fold(lines: [1, nil, 0, 2, nil], methods: { [Object, :b, 3, 2, 4, 5] => 2 })

    assert_equal [1, nil, 0, 2, nil], folded[:lines]
  end

  def test_should_leave_a_one_line_method_never_called_uncovered
    folded = fold(lines: [1, 1], methods: { [Object, :a, 2, 2, 2, 20] => 0 })

    assert_equal [1, 1], folded[:lines]
  end

  def test_should_leave_lines_without_method_counts_as_they_are
    assert_equal({ FILE => [1, 0] }, StatementCoverage.fold({ FILE => [1, 0] }, read: ->(_) { [] }))
  end

  private

  def fold(data, source = []) = StatementCoverage.fold({ FILE => data }, read: ->(_) { source }).fetch(FILE)
end
