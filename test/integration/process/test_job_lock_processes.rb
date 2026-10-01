# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/job_run_kit"
require_relative "../../support/process_deadline"
require "rbconfig"

# A job runs once at a time across processes: while another process holds
# the job's lock, a run starts nothing (acceptance-tests.md, AT-13.5).
class TestJobLockProcesses < Minitest::Test
  include JobRunKit
  include ProcessDeadline

  # Takes the job's lock, says so, and holds it until its input ends.
  HOLDER = <<~RUBY
    require "fileutils"
    FileUtils.mkdir_p(File.dirname(ARGV[0]))
    lock = File.open(ARGV[0], File::RDWR | File::CREAT)
    lock.flock(File::LOCK_EX)
    puts "held"
    $stdout.flush
    $stdin.read
  RUBY

  def test_should_start_nothing_while_another_process_holds_the_job_s_lock
    started = holding_in_another_process { run_job }

    assert_nil started
  end

  def test_should_run_the_job_once_the_other_process_let_go
    holding_in_another_process { nil }

    refute_nil run_job
  end

  private

  # The block's value, run while another process holds the job's lock; it lets go and is waited for after.
  # A process of its own, not a fork, which would inherit the test's open database connection.
  def holding_in_another_process
    holder = IO.popen([RbConfig.ruby, "-e", HOLDER, File.join(locks_root, "mutation.lock")], "r+")
    within_deadline { holder.gets }
    yield
  ensure
    holder&.close_write
    within_deadline { holder&.close }
  end
end
