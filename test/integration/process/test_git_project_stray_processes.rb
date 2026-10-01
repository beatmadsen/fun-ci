# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"

# A test that ends with a stage or job script still running in its project,
# blocked on a FIFO it never got to read, say, leaves it running for good.
# Removing the project kills it and fails the test, naming it.
class TestGitProjectStrayProcesses < Minitest::Test
  def setup
    @project = GitProject.create
    @project.write("blocked.sh", "#!/bin/sh\nsleep 20\n:\n", mode: 0o755)
    @script = File.join(File.realpath(@project.dir), "blocked.sh")
    @pid = Process.spawn(@script, out: File::NULL, err: File::NULL, pgroup: true)
  end

  def teardown = reaped

  def test_should_fail_naming_a_process_left_running_in_the_project
    error = assert_raises(GitProject::LeftRunning) { @project.remove }

    assert_includes error.message, @script
  end

  def test_should_kill_a_process_left_running_in_the_project
    assert_raises(GitProject::LeftRunning) { @project.remove }

    assert_equal "KILL", Signal.signame(reaped.termsig.to_i)
  end

  private

  def reaped = (@reaped ||= Process.wait2(@pid).last)
end
