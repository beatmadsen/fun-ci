# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/json_log"

# `json-log`: JSON log lines at or above a level, each as one line followed
# by its stack trace (architecture.md, "Evidence of a failed stage").
class TestJsonLog < Minitest::Test
  include EvidenceKit

  FIELDS = { "time" => "ts", "level" => "lvl", "logger" => "name", "message" => "msg", "stack" => "err.stack" }.freeze
  OUTPUT = <<~LOG
    starting
    {"ts":"10:00","lvl":"DEBUG","name":"db","msg":"connecting"}
    {"ts":"10:01","lvl":"WARN","name":"http","msg":"slow"}
    not json {
    {"ts":"10:02","lvl":"error","name":"pay","msg":"declined","err":{"stack":"Boom\\n  at pay.rb:3"}}
  LOG

  def test_should_keep_each_record_at_or_above_the_level_as_one_line
    assert_equal ["10:01 WARN http: slow", "10:02 ERROR pay: declined", "  Boom", "    at pay.rb:3"],
                 only_excerpt("level" => "warn")[:lines]
  end

  def test_should_keep_records_at_the_warn_level_by_default
    assert_equal "10:01 WARN http: slow", only_excerpt({})[:lines].first
  end

  def test_should_say_where_the_records_it_kept_are
    assert_equal "output:3-5", only_excerpt("level" => "warn")[:location]
  end

  def test_should_pass_over_lines_that_are_json_but_not_a_record
    output = %([1, 2]\n"error"\n{"ts":"1","lvl":"ERROR","name":"a","msg":"b"}\n)

    assert_equal ["1 ERROR a: b"], only_excerpt({}, output)[:lines]
  end

  def test_should_read_a_field_whose_name_holds_a_dot
    output = %({"ts":"1","log.level":"ERROR","name":"a","msg":"b"}\n)

    assert_equal ["1 ERROR a: b"], only_excerpt({ "fields" => FIELDS.merge("level" => "log.level") }, output)[:lines]
  end

  def test_should_read_levels_given_as_numbers
    output = %({"ts":"1","lvl":50,"name":"a","msg":"b"}\n{"ts":"2","lvl":30,"name":"a","msg":"c"}\n)

    assert_equal ["1 ERROR a: b"], only_excerpt({ "levels" => { "30" => "info", "50" => "error" } }, output)[:lines]
  end

  def test_should_take_warning_and_critical_as_warn_and_fatal
    output = %({"ts":"1","lvl":"warning","name":"a","msg":"b"}\n{"ts":"2","lvl":"critical","name":"a","msg":"c"}\n)

    assert_equal ["1 WARN a: b", "2 FATAL a: c"], only_excerpt({}, output)[:lines]
  end

  def test_should_leave_out_a_field_the_setup_does_not_name
    fields = FIELDS.except("logger")

    assert_equal "10:01 WARN slow", only_excerpt({ "fields" => fields })[:lines].first
  end

  # The stack field's path runs into a plain string here, not an object.
  def test_should_keep_a_record_whose_field_path_ends_early_without_that_field
    output = %({"ts":"1","lvl":"ERROR","name":"a","msg":"b","err":"plain"}\n)

    assert_equal ["1 ERROR a: b"], only_excerpt({}, output)[:lines]
  end

  def test_should_find_nothing_without_a_record_at_the_level
    assert_empty json_log({ "level" => "fatal" }, OUTPUT).excerpts
  end

  private

  def only_excerpt(options, output = OUTPUT) = json_log(options, output).excerpts.first

  def json_log(options, output)
    FunCi::Evidence::Extractors::JsonLog.new({ "fields" => FIELDS }.merge(options)).extract(context(output: output))
  end
end
