# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/section"

# `section`: the lines from a start pattern up to an end pattern (architecture.md, "Evidence of a failed stage").
class TestSection < Minitest::Test
  include EvidenceKit

  OUTPUT = "noise\nFailures:\n  1) a\n  2) b\nFinished in 1s\nmore noise\n"

  def test_should_keep_the_lines_from_the_start_up_to_the_end
    assert_equal ["Failures:", "  1) a", "  2) b"],
                 excerpts("start" => ["^Failures:"], "end" => ["^Finished"]).first[:lines]
  end

  def test_should_say_where_the_section_is
    assert_equal "output:2-4", excerpts("start" => ["^Failures:"], "end" => ["^Finished"]).first[:location]
  end

  def test_should_keep_to_the_end_of_the_output_without_an_end_pattern
    assert_equal "output:2-6", excerpts("start" => ["^Failures:"]).first[:location]
  end

  def test_should_keep_each_section_that_starts
    output = "START\na\nEND\nx\nSTART\nb\nEND\n"

    assert_equal(%w[output:1-2 output:5-6], section({ "start" => ["START"], "end" => ["END"] }, output).map do |e|
      e[:location]
    end)
  end

  def test_should_start_the_next_section_on_the_line_that_ends_the_last
    output = "  1) a\n  detail\n  2) b\n  detail\nsummary\n"

    assert_equal(%w[output:1-2 output:3-4],
                 section({ "start" => ['^  \d\) '], "end" => ['^  \d\) ', "^summary"] }, output).map do |e|
                   e[:location]
                 end)
  end

  def test_should_start_on_any_of_its_start_patterns
    assert_equal(["output:2-4"], excerpts("start" => %w[^nothing ^Failures:], "end" => ["^Finished"]).map do |e|
      e[:location]
    end)
  end

  def test_should_cut_a_section_at_its_line_limit
    found = excerpts("start" => ["^Failures:"], "end" => ["^Finished"], "lines" => 2).first

    assert_equal [["Failures:", "  1) a"], true], [found[:lines], found[:truncated]]
  end

  def test_should_title_its_excerpts_as_it_is_told
    assert_equal "rspec failures", excerpts("start" => ["^Failures:"], "title" => "rspec failures").first[:title]
  end

  def test_should_leave_out_the_blank_lines_a_section_ends_with
    assert_equal "output:1-2",
                 section({ "start" => ["START"], "end" => ["END"] }, "START\na\n\n  \nEND\n").first[:location]
  end

  def test_should_find_nothing_when_no_section_starts
    assert_empty excerpts("start" => ["^PANIC"])
  end

  private

  def excerpts(options) = section(options, OUTPUT)

  def section(options, output)
    FunCi::Evidence::Extractors::Section.new(options).extract(context(output: output)).excerpts
  end
end
