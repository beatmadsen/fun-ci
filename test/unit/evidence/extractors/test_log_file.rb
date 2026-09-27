# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/log_file"

# `log-file`: what a stage wrote to the files under a glob (why.md).
class TestLogFile < Minitest::Test
  include EvidenceKit

  OLD = "old one\nold two\n"
  NEW = "new one\nERROR new two\nnew three\n"

  def test_should_keep_what_was_written_after_the_stage_started
    assert_equal ["new one", "ERROR new two", "new three"],
                 only_excerpt({}, watched: { "log/test.log" => stamp(16) })[:lines]
  end

  def test_should_number_the_lines_from_where_the_file_stood
    assert_equal "log/test.log:3-5", only_excerpt({}, watched: { "log/test.log" => stamp(16) })[:location]
  end

  def test_should_read_a_file_the_stage_created_whole
    assert_equal "log/test.log:1-5", only_excerpt({}, watched: {})[:location]
  end

  def test_should_leave_out_a_file_the_stage_did_not_change
    assert_empty log_file({}, watched: { "log/test.log" => stamp(48) }).excerpts
  end

  def test_should_read_a_file_whose_time_changed_though_its_size_did_not
    assert_equal "log/test.log:1-5", only_excerpt({}, watched: { "log/test.log" => stamp(48, mtime: 5) })[:location]
  end

  def test_should_read_a_file_that_grew_shorter_from_its_start
    assert_equal "log/test.log:1-5", only_excerpt({}, watched: { "log/test.log" => stamp(900) })[:location]
  end

  def test_should_say_a_file_that_grew_shorter_was_truncated_or_rotated
    assert_equal [{ name: "truncated", value: "log/test.log" }],
                 log_file({}, watched: { "log/test.log" => stamp(900) }).facts
  end

  def test_should_read_a_file_replaced_by_another_from_its_start
    assert_equal "log/test.log:1-5", only_excerpt({}, watched: { "log/test.log" => stamp(16, inode: 2) })[:location]
  end

  def test_should_keep_only_the_lines_matching_its_grep_patterns
    assert_equal ["ERROR new two"],
                 only_excerpt({ "grep" => ["ERROR"] }, watched: { "log/test.log" => stamp(16) })[:lines]
  end

  def test_should_keep_a_section_when_given_a_start
    assert_equal ["ERROR new two", "new three"],
                 only_excerpt({ "start" => ["ERROR"] }, watched: { "log/test.log" => stamp(16) })[:lines]
  end

  def test_should_keep_the_last_lines_it_is_told_to
    assert_equal ["ERROR new two", "new three"],
                 only_excerpt({ "lines" => 2 }, watched: { "log/test.log" => stamp(16) })[:lines]
  end

  private

  def only_excerpt(options, watched:) = log_file(options, watched: watched).excerpts.first

  def log_file(options, watched:)
    context = context(files: { "log/test.log" => OLD + NEW }, watched: watched)
    FunCi::Evidence::Extractors::LogFile.new({ "path" => "log/*.log" }.merge(options)).extract(context)
  end
end
