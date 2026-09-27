# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/stage_dir"

# A stage's own directory: the empty directory it may write test reports
# into (AT-9.7), and the window its output is written to (AT-10.6).
class TestStageDir < Minitest::Test
  JUNIT = %(<testsuite><testcase name="t1"><failure message="m1"/></testcase></testsuite>)
  SIZES = FunCi::Pipeline::OutputWindow::Sizes.new(head: 4, tail: 4)

  def setup
    @root = Dir.mktmpdir
    @reports = FunCi::Pipeline::StageDir.create(@root)
  end

  def teardown
    @reports.remove
    FileUtils.remove_entry(@root)
  end

  def test_should_make_its_directory_under_the_root_named_for_the_process
    assert File.basename(Dir.children(@root).first).start_with?("#{Process.pid}-")
  end

  def test_should_write_the_window_into_its_directory
    @reports.window(SIZES) << "aaaaaaaaaaaaaaaaaaaa"

    assert_equal %w[head reports tail-0 tail-1], Dir.children(File.join(@root, Dir.children(@root).first)).sort
  end

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
