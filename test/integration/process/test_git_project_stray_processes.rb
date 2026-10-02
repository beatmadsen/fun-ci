# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"

# A test that ends with a stage or job script still running in its project,
# blocked on a FIFO it never got to read, say, leaves it running for good.
# Removing the project kills it and fails the test, naming it.
class TestGitProjectStrayProcesses < Minitest::Test
  include ProcessDeadline

  # The script waits, forking nothing, for input only teardown ends, and says
  # it started once it runs: until then ps shows it by this process's command
  # line, which names no project.
  def setup
    @project = GitProject.create
    @project.write("blocked.sh", "#!/bin/sh\necho started\nread _\n", mode: 0o755)
    @pid = blocked
  end

  def teardown
    @hold.close
    reaped
  end

  def test_should_fail_naming_a_process_left_running_in_the_project
    running = script
    error = assert_raises(GitProject::LeftRunning) { @project.remove }

    assert_includes error.message, running
  end

  def test_should_kill_a_process_left_running_in_the_project
    assert_raises(GitProject::LeftRunning) { @project.remove }

    assert_equal "KILL", Signal.signame(reaped.termsig.to_i)
  end

  private

  def script = File.join(File.realpath(@project.dir), "blocked.sh")
  def reaped = (@reaped ||= Process.wait2(@pid).last)

  def blocked
    reader, writer = IO.pipe
    input, @hold = IO.pipe
    pid = Process.spawn(script, in: input, out: writer, err: File::NULL, pgroup: true)
    [writer, input].each(&:close)
    within_deadline { reader.gets }
    pid
  end
end
