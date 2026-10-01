# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/jobs/locks"
require "tmpdir"

# Each job's lock, which whoever runs the job holds (acceptance-tests.md, AT-13.5).
class TestJobLocks < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @locks = FunCi::Jobs::Locks.new(File.join(@dir, "jobs"))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_hand_out_a_job_s_worktree_beside_its_lock
    slot = @locks.take("soak")

    assert_equal File.join(@dir, "jobs", "soak"), slot.path
  ensure
    slot&.release
  end

  def test_should_hand_out_nothing_while_the_job_s_lock_is_held
    held = @locks.take("soak")

    assert_nil @locks.take("soak")
  ensure
    held&.release
  end

  # A trigger that finds the job running leaves no file open behind it.
  def test_should_close_the_lock_file_it_could_not_lock
    held = @locks.take("soak")
    before = open_files
    @locks.take("soak")

    assert_equal before, open_files
  ensure
    held&.release
  end

  private

  def open_files = ObjectSpace.each_object(File).count { |file| !file.closed? }
end
