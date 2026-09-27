# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/report_dir"

# The empty directory a stage may write test reports into (AT-9.7).
class TestReportDir < Minitest::Test
  JUNIT = %(<testsuite><testcase name="t1"><failure message="m1"/></testcase></testsuite>)

  def setup = @reports = FunCi::Pipeline::ReportDir.create
  def teardown = @reports.remove

  def test_should_name_an_empty_directory_for_the_stage
    assert_empty Dir.children(@reports.env.fetch("FUN_CI_REPORT"))
  end

  def test_should_read_the_failures_of_every_report_in_it
    write("a.xml", JUNIT)
    write("b.json", %({"failures": [{"test": "t2", "message": "m2"}]}))

    assert_equal %w[t1 t2], @reports.failures.map { |failure| failure[:test] }.sort
  end

  def test_should_skip_a_report_it_cannot_read
    write("broken.xml", "<testsuite")
    write("good.xml", JUNIT)

    assert_equal(%w[t1], @reports.failures.map { |failure| failure[:test] })
  end

  def test_should_ignore_files_that_are_not_reports
    write("notes.txt", "hello")

    assert_empty @reports.failures
  end

  def test_should_remove_the_directory
    path = @reports.env.fetch("FUN_CI_REPORT")
    @reports.remove

    refute Dir.exist?(path)
  end

  private

  def write(name, content) = File.write(File.join(@reports.env.fetch("FUN_CI_REPORT"), name), content)
end
