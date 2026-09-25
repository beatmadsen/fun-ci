# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"
require "fun_ci/pipeline/worktree_pool"

# AT-1.4: with one slot, a second pipeline waits while the first one's slow
# suite still holds it, and is recorded as pending, not running, until then.
# The first slow suite is held back by the test and let go from the waiter.
class TestSlotWaiting < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  Worktrees = Struct.new(:root) { def check_out(_path, _sha) = nil }
  # What happened, what the second run had recorded while it waited, and the
  # first run's slow suite, held back.
  Scenario = Struct.new(:events, :second, :calls_while_waiting, :held_slow_suite)

  def setup
    @root = Dir.mktmpdir("worktrees")
    @run = Scenario.new([], FakeRecorder.new)
  end

  def teardown = FileUtils.rm_rf(@root)

  def test_the_second_pipeline_waits_for_the_slot
    run_both

    assert_equal 1, @run.events.count(:waited)
  end

  def test_the_second_pipeline_is_pending_while_it_waits
    run_both

    assert_equal [[:create_run, "def5678", "main", @dir]], @run.calls_while_waiting
  end

  def test_the_second_pipeline_starts_only_after_the_first_slow_suite_has_finished
    run_both

    assert_equal ["slow.sh", :first_slow_finished], @run.events[@run.events.index(:waited) + 1, 2]
  end

  private

  def run_both
    in_project do |dir|
      @dir = dir
      build_trigger(dir, command_runner: logging_runner, workspace: pool, background_launcher: hold_slow_suite).run
      build_trigger(dir, sha: "def5678", command_runner: logging_runner, workspace: pool, recorder: @run.second).run
    end
  end

  def pool = FunCi::Pipeline::WorktreePool.new(Worktrees.new(@root), size: 1, waiter: method(:wait))
  def hold_slow_suite = ->(executor:, **) { @run.held_slow_suite = executor }
  def logging_runner = ->(cmd) { (@run.events << File.basename(cmd.split.first)) && PASS }

  def wait
    @run.events << :waited
    @run.calls_while_waiting = @run.second.calls.dup
    @run.held_slow_suite.call
    @run.events << :first_slow_finished
  end
end
