# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/junit_files"

# `junit-files`: the failures in JUnit XML a build tool wrote in its own
# place during the stage (why.md).
class TestJunitFiles < Minitest::Test
  include EvidenceKit

  XML = %(<testsuite><testcase classname="CartTest" name="adds"><failure message="off by one"/></testcase></testsuite>)

  def test_should_read_the_failures_in_the_files_under_its_globs
    assert_equal(["CartTest#adds"], failures_found({}).map { |failure| failure[:test] })
  end

  def test_should_leave_out_a_report_the_stage_did_not_write
    assert_empty failures_found({ "build/test-results/TEST-CartTest.xml" => stamp(XML.bytesize) })
  end

  def test_should_skip_a_report_it_cannot_read
    context = context(files: { "build/test-results/TEST-Broken.xml" => "<testsuite" })

    assert_empty junit_files.extract(context).failures
  end

  private

  def junit_files = FunCi::Evidence::Extractors::JunitFiles.new({ "paths" => ["build/test-results/*.xml"] })

  def failures_found(watched)
    junit_files.extract(context(files: { "build/test-results/TEST-CartTest.xml" => XML }, watched: watched)).failures
  end
end
