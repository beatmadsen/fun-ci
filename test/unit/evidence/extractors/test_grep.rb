# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/grep"

# `grep`: the lines matching patterns, with lines of context around each (why.md).
class TestGrep < Minitest::Test
  include EvidenceKit

  OUTPUT = "one\ntwo\nERROR three\nfour\nfive\nsix\nFATAL seven\neight\n"

  def test_should_keep_each_line_matching_a_pattern
    assert_equal([["ERROR three"], ["FATAL seven"]], excerpts("patterns" => %w[ERROR FATAL]).map { |e| e[:lines] })
  end

  def test_should_say_where_each_run_of_lines_came_from
    assert_equal "output:3", excerpts("patterns" => %w[ERROR]).first[:location]
  end

  def test_should_title_its_excerpts_with_the_patterns
    assert_equal "Lines matching ERROR or FATAL", excerpts("patterns" => %w[ERROR FATAL]).first[:title]
  end

  def test_should_keep_lines_of_context_around_a_match
    assert_equal([["two", "ERROR three", "four"]], excerpts("patterns" => %w[ERROR], "context" => 1).map do |e|
      e[:lines]
    end)
  end

  def test_should_join_matches_whose_context_overlaps
    assert_equal(["output:1-8"], excerpts("patterns" => %w[ERROR FATAL], "context" => 2).map { |e| e[:location] })
  end

  def test_should_read_a_file_in_the_worktree_when_given_a_path
    found = grep({ "patterns" => %w[boom], "path" => "log/test.log" },
                 context(files: { "log/test.log" => "ok\nboom\n" }))

    assert_equal "log/test.log:2", found.excerpts.first[:location]
  end

  def test_should_find_nothing_in_output_without_a_match
    assert_empty excerpts("patterns" => %w[PANIC])
  end

  def test_should_stop_at_the_deadline_with_what_it_found
    output = "ERROR first\n#{"x\n" * 3000}ERROR last\n"
    found = grep({ "patterns" => %w[ERROR] }, context(output: output, deadline: PassingDeadline.new(1)))

    assert_equal [["ERROR first"], true], [found.excerpts.map do |e|
      e[:lines]
    end.flatten, found.excerpts.first[:truncated]]
  end

  private

  def excerpts(options) = grep(options, context(output: OUTPUT)).excerpts
  def grep(options, context) = FunCi::Evidence::Extractors::Grep.new(options).extract(context)
end
