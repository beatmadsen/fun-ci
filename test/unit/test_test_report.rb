# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/test_report"

class TestTestReport < Minitest::Test
  REPORT = FunCi::Pipeline::TestReport

  def test_should_read_a_junit_failure_with_its_file_line_test_and_text
    xml = %(<testsuite><testcase classname="FetchTest" name="test_retry" file="t.rb" line="41">) +
          %(<failure message="short">Expected 3\ngot 1</failure></testcase></testsuite>)

    assert_equal [{ file: "t.rb", line: 41, test: "FetchTest#test_retry", message: "Expected 3\ngot 1" }],
                 REPORT.junit(xml)
  end

  def test_should_read_a_junit_error_like_a_failure
    xml = %(<testsuite><testcase name="test_boom"><error message="RuntimeError: boom"/></testcase></testsuite>)

    assert_equal [{ file: nil, line: nil, test: "test_boom", message: "RuntimeError: boom" }], REPORT.junit(xml)
  end

  def test_should_leave_out_junit_tests_that_passed_or_were_skipped
    xml = %(<testsuites><testsuite><testcase name="ok"/><testcase name="later"><skipped/></testcase>) +
          %(</testsuite></testsuites>)

    assert_empty REPORT.junit(xml)
  end

  def test_should_read_nothing_from_xml_it_cannot_parse
    assert_nil REPORT.junit("<testsuite><testcase")
  end

  def test_should_read_fun_ci_s_json
    json = %({"failures": [{"file": "a.rb", "line": 3, "test": "lint", "message": "bad"}]})

    assert_equal [{ file: "a.rb", line: 3, test: "lint", message: "bad" }], REPORT.json(json)
  end

  def test_should_read_nothing_from_json_without_a_list_of_failures
    assert_nil REPORT.json(%({"oops": true}))
  end

  def test_should_read_nothing_from_text_that_is_not_json
    assert_nil REPORT.json("not json")
  end
end
