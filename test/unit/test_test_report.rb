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

  # One such entry made the whole of a failed stage's evidence be lost.
  def test_should_keep_a_junit_failure_s_own_output_and_errors
    xml = %(<testsuite><testcase name="t"><failure message="m"/><system-out>printed</system-out>) +
          %(<system-err>warned</system-err></testcase></testsuite>)

    assert_equal "printed\nwarned", REPORT.junit(xml).first[:output]
  end

  def test_should_keep_the_last_4_kb_of_a_failure_s_own_output
    xml = "<testsuite><testcase name=\"t\"><failure message=\"m\"/><system-out>#{"x" * 5000}END</system-out>" \
          "</testcase></testsuite>"

    assert_equal "#{"x" * 4093}END", REPORT.junit(xml).first[:output]
  end
end
