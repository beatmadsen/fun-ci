# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/probe_suite"
require_relative "../../support/process_deadline"
require "securerandom"

# Nothing a test run starts outlives it. A stage or job script a failed test
# left blocked ran on for hours, holding its job's lock, after its temp root
# was gone; at the end of a run, any process that names the run's temp root
# is killed, and the run fails, naming it.
class TestProcessLeakGuard < Minitest::Test
  include ProcessDeadline

  def setup = @marker = "leak-#{SecureRandom.hex(6)}"

  # Ends what `started` started, if nothing killed it.
  def teardown = @hold&.close

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
    assert_predicate ProbeSuite.capture("Process.wait(#{spawn_naming_the_root})").last, :success?
  end

  # The mutation lane, and a run cut short, never reach the end of a run; the
  # next run stops what is left in the temp root of one that has finished.
  # The roots are in a directory of this test's own: the probes of tests in
  # other workers clear finished roots in the run's temp root, and one that
  # cleared this one before its process started would leave nothing to find.
  # Its name is short, since the probe's own root goes in it, and the parallel
  # executor's socket in that, whose path is capped at 104 bytes.
  def test_a_run_stops_what_is_left_running_from_a_finished_run
    parent = File.join(Dir.tmpdir, "r#{Process.pid}").tap { |dir| Dir.mkdir(dir) }
    left = started(File.join(finished_root(parent), @marker))
    ProbeSuite.capture("nil", env: { "TMPDIR" => parent })

    assert_equal "KILL", Signal.signame(within_deadline { Process.wait2(left) }.last.termsig.to_i)
  end

  private

  # A temp root named for a process that is not running, as a finished run's
  # is. No pid is that high on Linux or macOS, so none can reuse it, as one
  # that had exited could while the test ran.
  def finished_root(parent) = File.join(parent, "fci-99999999").tap { |root| Dir.mkdir(root) }

  # A shell named `name` that waits, forking nothing, for input only teardown
  # ends. It says it started once it runs: until it has exec'd, ps shows it by
  # this process's command line, which names no root. One that slept in a
  # child instead had that child killed alone, now and then, on a busy machine.
  def started(name)
    reader, writer = IO.pipe
    input, @hold = IO.pipe
    pid = Process.spawn("sh", "-c", "echo started; read _", name, in: input, out: writer, err: File::NULL, pgroup: true)
    [writer, input].each(&:close)
    within_deadline { reader.gets }
    pid
  end

  # A shell named by a path in the run's temp root, which sleeps on alone.
  def leaking_run = ProbeSuite.capture("Process.detach(#{spawn_naming_the_root(seconds: 20)})")

  # The probe's code for such a shell, answering its pid once it has said it started.
  def spawn_naming_the_root(seconds: 0)
    "IO.pipe.then { |r, w| Process.spawn('sh', '-c', 'echo started; sleep #{seconds}; :', " \
      "File.join(Dir.tmpdir, '#{@marker}'), out: w, err: File::NULL, pgroup: true)" \
      ".tap { w.close; r.gets } }"
  end
end
