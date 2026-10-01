# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/probe_suite"
require "securerandom"

# Nothing a test run starts outlives it. A stage or job script a failed test
# left blocked ran on for hours, holding its job's lock, after its temp root
# was gone; at the end of a run, any process that names the run's temp root
# is killed, and the run fails, naming it.
class TestProcessLeakGuard < Minitest::Test
  def setup = @marker = "leak-#{SecureRandom.hex(6)}"

  def test_a_run_that_leaves_a_process_running_fails
    refute_predicate leaking_run.last, :success?
  end

  def test_a_run_that_leaves_a_process_running_names_it
    assert_match(/#{@marker}/, leaking_run.first)
  end

  def test_a_run_that_leaves_a_process_running_kills_it
    leaking_run

    assert_empty `ps -A -o command=`.lines.grep(/#{@marker}/)
  end

  def test_a_run_that_waits_for_its_processes_passes
    assert_predicate ProbeSuite.capture(%(Process.wait(#{spawn_naming_the_root}))).last, :success?
  end

  # The mutation lane, and a run cut short, never reach the end of a run; the
  # next run stops what is left in the temp root of one that has finished.
  def test_a_run_stops_what_is_left_running_from_a_finished_run
    left = Process.spawn("sh", "-c", "sleep 20; :", File.join(finished_root, @marker),
                         out: File::NULL, err: File::NULL, pgroup: true)
    ProbeSuite.capture("nil")

    assert_equal "KILL", Signal.signame(Process.wait2(left).last.termsig.to_i)
  end

  private

  # A temp root named for a process that has exited, as a finished run's is.
  def finished_root
    pid = Process.spawn("true")
    Process.wait(pid)
    File.join(Dir.tmpdir, "fci-#{pid}").tap { |root| Dir.mkdir(root) }
  end

  # A shell named by a path in the run's temp root, which sleeps on alone.
  def leaking_run = ProbeSuite.capture(%(Process.detach(#{spawn_naming_the_root(seconds: 20)})))

  def spawn_naming_the_root(seconds: 0)
    "Process.spawn('sh', '-c', 'sleep #{seconds}; :', File.join(Dir.tmpdir, '#{@marker}'), " \
      "out: File::NULL, err: File::NULL, pgroup: true)"
  end
end
