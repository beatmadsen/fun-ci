# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/output_window"

# A stage's output kept as its first and last bytes, cut on line ends
# (why.md, "The budget, and what bounds the built-ins").
class TestOutputWindow < Minitest::Test
  WINDOW = FunCi::Pipeline::OutputWindow
  SIZES = WINDOW::Sizes.new(head: 10, tail: 12)

  def test_should_keep_output_that_fits_whole
    assert_equal "one\ntwo\n", window("one\ntwo\n").text
  end

  def test_should_keep_output_that_just_fits_both_ends_whole
    assert_equal "0123456789abcdefghijkl", window("0123456789", "abcdefghijkl").text
  end

  def test_should_cut_the_first_part_at_its_last_line_end
    assert window("aaa\nbbb\nccccc\n", "x" * 30, "\nyyy\n").text.start_with?("aaa\nbbb\n[fun-ci:")
  end

  def test_should_start_the_last_part_after_its_first_line_end
    assert window("aaa\n", "x" * 30, "zz\nyyy\nwww\n").text.end_with?("here]\nyyy\nwww\n")
  end

  def test_should_keep_a_last_part_that_starts_on_a_line_start_whole
    assert window("aaa\n", "x" * 30, "\nqqqqq\nwwwww\n").text.end_with?("here]\nqqqqq\nwwwww\n")
  end

  def test_should_say_how_many_bytes_it_dropped_between_the_parts
    assert_includes window("aaa\nbbb\n", "x" * 30, "\nyyy\n").text, "\n[fun-ci: 31 bytes dropped here]\n"
  end

  def test_should_cut_mid_line_when_a_line_is_longer_than_the_window
    assert_equal "0123456789[fun-ci: 8 bytes dropped here]\nMNOPQRSTUVWX", window(("0".."9").to_a.join, "abcdefgh",
                                                                                  ("M".."X").to_a.join).text
  end

  def test_should_keep_the_end_of_a_line_longer_than_the_last_part
    assert_equal "0123456789[fun-ci: 9 bytes dropped here]\nNOPQRSTUVWX\n",
                 window(("0".."9").to_a.join, "abcdefghM", "NOPQRSTUVWX\n").text
  end

  def test_should_keep_the_last_part_across_many_writes
    assert window("aaa\n", *Array.new(40, "x\n"), "end\n").text.end_with?("x\nx\nx\nx\nend\n")
  end

  def test_should_keep_text_that_is_not_ascii_when_its_last_part_wraps_around
    assert window("aaaaaaaaaa", "é" * 20, "\n").text.b.end_with?("ééééé\n".b)
  end

  def test_should_close_every_io_it_opened
    opened = []
    window = WINDOW.new(->(_name) { StringIO.new(+"").tap { |io| opened << io } }, SIZES)
    window << ("x" * 40)
    window.close

    assert(opened.all?(&:closed?))
  end

  private

  def window(*chunks)
    WINDOW.in_memory(SIZES).tap { |window| chunks.each { |chunk| window << chunk } }
  end
end
