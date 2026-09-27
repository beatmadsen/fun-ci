# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/excerpt_comparison"

# How script/check_evidence_presets.rb decides whether what a preset picks out
# of a fresh run of its tool changed: only what differs from run to run of
# the same release is left out.
class TestExcerptComparison < Minitest::Test
  def same?(before, after) = ExcerptComparison.same?(before, after)

  def test_should_leave_out_decimal_numbers
    assert same?([["took 0.12s, pid 41"]], [["took 3.4s, pid 977"]])
  end

  def test_should_leave_out_hexadecimal_addresses
    assert same?([["<Cart object at 0xffffba046120>"]], [["<Cart object at 0xffff9f4a6120>"]])
  end

  def test_should_leave_out_the_order_the_excerpts_came_in
    assert same?([["1) test a"], ["2) test b"]], [["2) test b"], ["1) test a"]])
  end

  def test_should_see_a_changed_line
    refute same?([["Assertion with == failed"]], [["Assertion failed"]])
  end

  def test_should_see_a_line_in_a_different_excerpt
    refute same?([%w[a b], ["c"]], [["a"], %w[b c]])
  end
end
