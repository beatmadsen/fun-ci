# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/stage_dir"

# A stage's own directory, which holds the window its output is written to
# (AT-10.6) and what a project's extractor reads and writes.
class TestStageDir < Minitest::Test
  SIZES = FunCi::Pipeline::OutputWindow::Sizes.new(head: 4, tail: 4)

  def setup
    @root = Dir.mktmpdir
    @stage_dir = FunCi::Pipeline::StageDir.create(@root)
  end

  def teardown
    @stage_dir.remove
    FileUtils.remove_entry(@root)
  end

  def test_should_make_its_directory_under_the_root_named_for_the_process
    assert File.basename(Dir.children(@root).first).start_with?("#{Process.pid}-")
  end

  def test_should_write_the_window_into_its_directory
    @stage_dir.window(SIZES) << "aaaaaaaaaaaaaaaaaaaa"

    assert_equal %w[head tail-0 tail-1], Dir.children(@stage_dir.scratch).sort
  end

  def test_should_remove_the_directory
    path = @stage_dir.scratch
    @stage_dir.remove

    refute Dir.exist?(path)
  end
end
