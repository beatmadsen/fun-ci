# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/output_tail"

class TestOutputTail < Minitest::Test
  TAIL = FunCi::Persistence::OutputTail

  def test_should_keep_the_last_200_lines
    output = (1..250).map { |n| "line #{n}\n" }.join

    assert_equal (51..250).map { |n| "line #{n}\n" }.join, TAIL.of(output)
  end

  def test_should_keep_all_of_a_shorter_output
    assert_equal "one\ntwo\n", TAIL.of("one\ntwo\n")
  end

  def test_should_strip_colour_codes
    assert_equal "red plain\n", TAIL.of("\e[1;31mred\e[0m plain\n")
  end

  def test_should_keep_at_most_sixty_four_kilobytes_from_the_end
    output = "#{"a" * 70_000}\nlast line\n"

    assert_equal 65_536, TAIL.of(output).bytesize
  end

  def test_should_not_cut_a_character_in_half_at_the_size_limit
    assert_predicate TAIL.of("é" * 40_000), :valid_encoding?
  end

  def test_should_read_output_that_is_not_valid_utf8
    assert_equal "bad ? byte\n", TAIL.of((+"bad \xff byte\n").force_encoding("BINARY"))
  end
end
