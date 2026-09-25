# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

# A pipeline lets go of its worktree slot when the last stage that uses it
# finishes, and not before.
class TestTriggerSlot < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_lets_go_of_the_slot_when_the_pipeline_finishes
    assert_predicate lock_after(background_launcher: inline_launcher), :closed?
  end

  def test_lets_go_of_the_slot_when_phase_one_fails
    assert_predicate lock_after(runner: scripted_runner({ "lint.sh" => failing("lint errors") })), :closed?
  end

  def test_keeps_the_slot_while_the_slow_suite_is_still_running
    refute_predicate lock_after(background_launcher: ->(**) {}), :closed?
  end

  def test_lets_go_of_the_slot_when_the_slow_suite_finishes_after_the_fast_suite
    slow = nil
    lock = lock_after(background_launcher: ->(executor:, **) { slow = executor })
    slow.call

    assert_predicate lock, :closed?
  end

  private

  def lock_after(runner: scripted_runner, **seams)
    in_project do |dir|
      workspace = RecordingWorkspace.new(dir)
      build_trigger(dir, workspace: workspace, command_runner: runner, **seams).run
      workspace.lock
    end
  end
end
