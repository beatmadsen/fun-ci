# frozen_string_literal: true

require_relative "../test_helper"

# Each test run's startup clears the temp roots of runs that have ended,
# stopping what still runs in them. A mutation run leaves a root per mutant,
# hundreds, so asking ps once per root took 21 s and ran the next fast stage
# past its 10 s budget: ps is asked once for them all.
class TestConfinementSweep < Minitest::Test
  # Over any pid the system hands out, so no process has it.
  NO_SUCH_PID = 99_999_999

  # Stands in for StrayProcesses, recording the directories of each call.
  class Stopper
    attr_reader :calls

    def initialize = @calls = []

    def stop(dirs)
      @calls << dirs
      []
    end
  end

  def setup
    @roots = Array.new(3) { |i| File.join(Dir.tmpdir, "fci-#{NO_SUCH_PID - i}").tap { |root| Dir.mkdir(root) } }
    @stopper = Stopper.new
  end

  def teardown = FileUtils.rm_rf(@roots)

  def test_should_ask_for_the_processes_of_every_ended_run_s_root_at_once
    ConfinementGuard.remove_roots_of_finished_runs(stopper: @stopper)

    assert_equal 1, @stopper.calls.size
  end

  def test_should_remove_every_ended_run_s_root
    ConfinementGuard.remove_roots_of_finished_runs(stopper: @stopper)

    assert(@roots.none? { |root| File.exist?(root) })
  end
end
