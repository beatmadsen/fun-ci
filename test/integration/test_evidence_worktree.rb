# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/evidence/worktree"

# The files of the worktree a stage ran in, as extractors read them.
class TestEvidenceWorktree < Minitest::Test
  SIZES = FunCi::Pipeline::OutputWindow::Sizes.new(head: 4, tail: 4)

  def setup
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, "log"))
    File.write(File.join(@dir, "log", "test.log"), "one\ntwo\nthree\n")
    @worktree = FunCi::Evidence::Worktree.new(@dir)
  end

  def teardown = FileUtils.remove_entry(@dir)

  def test_should_read_a_file_from_an_offset
    assert_equal "two\nthree\n", @worktree.read("log/test.log", from: 4)
  end

  def test_should_read_a_long_file_through_a_window
    assert_includes FunCi::Evidence::Worktree.new(@dir, SIZES).read("log/test.log"), "bytes dropped here]"
  end

  def test_should_count_the_lines_before_an_offset
    assert_equal 2, @worktree.lines_before("log/test.log", 8)
  end

  def test_should_stamp_a_file_with_its_size_time_and_inode
    stat = File.stat(File.join(@dir, "log", "test.log"))

    assert_equal [14, stat.mtime.to_r, stat.ino], @worktree.stamp("log/test.log").to_h.values
  end

  def test_should_find_the_files_under_a_glob
    assert_equal ["log/test.log"], @worktree.glob("log/*.log")
  end
end
