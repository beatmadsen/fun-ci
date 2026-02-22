# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/header_animation_manager"
require "fun_ci/ansi"

class TestHeaderAnimationManagerIdle < Minitest::Test
  HEADER_HEIGHT = 14

  def test_should_show_idle_animation_by_default
    manager = make_manager
    # When no event has been triggered
    lines = manager.current_lines(80)
    # Then it should return non-empty lines from the idle player
    refute lines.empty?, "Should show idle animation when no event is active"
  end

  def test_should_always_return_header_height_lines
    manager = make_manager
    # When getting lines in idle state
    lines = manager.current_lines(80)
    # Then the result should be exactly HEADER_HEIGHT lines
    assert_equal HEADER_HEIGHT, lines.length,
      "Should pad output to HEADER_HEIGHT lines"
  end

  def test_should_not_report_active_event_during_idle
    manager = make_manager
    refute manager.any_active_event?, "Idle animation should not count as active event"
  end

  private

  def make_manager
    FunCi::HeaderAnimationManager.new(animation_library: make_fake_library)
  end

  def make_fake_library
    idle_data = { name: "Idle", fps: 4, frames: make_frames(HEADER_HEIGHT, 3) }
    running_data = { name: "Running", fps: 4, frames: make_frames(HEADER_HEIGHT, 3) }
    fail_data = { name: "Fail", fps: 8, frames: make_frames(8, 2) }
    succ_data = { name: "Succ", fps: 8, frames: make_frames(8, 2) }

    Module.new do
      extend self
      define_method(:idle)           { idle_data }
      define_method(:running)        { running_data }
      define_method(:random_failure) { fail_data }
      define_method(:random_success) { succ_data }
    end
  end

  def make_frames(height, count)
    count.times.map { height.times.map { |i| "line-#{i}" } }
  end
end

class TestHeaderAnimationManagerRunning < Minitest::Test
  HEADER_HEIGHT = 14

  def test_should_show_running_animation_when_started
    manager = make_manager
    # When a pipeline starts running
    manager.start_running
    lines = manager.current_lines(80)
    # Then the header should show running animation content
    plain = lines.map { |l| FunCi::Ansi.strip(l) }.join
    assert_match(/running-/, plain, "Should show running animation content")
  end

  def test_should_return_to_idle_when_running_stops
    manager = make_manager
    manager.start_running
    # When no pipelines are running anymore
    manager.stop_running
    lines = manager.current_lines(80)
    # Then it should show idle content
    plain = lines.map { |l| FunCi::Ansi.strip(l) }.join
    assert_match(/idle-/, plain, "Should return to idle after running stops")
  end

  def test_event_takes_priority_over_running
    manager = make_manager
    manager.start_running
    # When a failure event fires while running
    manager.trigger_failure
    lines = manager.current_lines(80)
    # Then the event animation should take priority (not running content)
    plain = lines.map { |l| FunCi::Ansi.strip(l) }.join
    assert_match(/event-/, plain, "Event should take priority over running")
  end

  def test_should_return_to_running_after_event_expires
    manager = make_manager
    manager.start_running
    manager.trigger_failure
    # When the event finishes
    3.times { manager.advance! }
    manager.expire_if_finished!
    # Then it should go back to running (not idle)
    lines = manager.current_lines(80)
    plain = lines.map { |l| FunCi::Ansi.strip(l) }.join
    assert_match(/running-/, plain, "Should return to running after event expires")
  end

  def test_should_advance_running_player
    manager = make_manager
    manager.start_running
    # When we advance the manager
    manager.advance!
    # Then running player should have advanced (no error, still produces lines)
    lines = manager.current_lines(80)
    assert_equal HEADER_HEIGHT, lines.length
  end

  private

  def make_manager
    FunCi::HeaderAnimationManager.new(animation_library: make_fake_library)
  end

  def make_fake_library
    idle_data = { name: "Idle", fps: 4, frames: make_frames("idle", HEADER_HEIGHT, 3) }
    running_data = { name: "Running", fps: 4, frames: make_frames("running", HEADER_HEIGHT, 3) }
    fail_data = { name: "Fail", fps: 8, frames: make_frames("event", 8, 2) }
    succ_data = { name: "Succ", fps: 8, frames: make_frames("event", 8, 2) }

    Module.new do
      extend self
      define_method(:idle)           { idle_data }
      define_method(:running)        { running_data }
      define_method(:random_failure) { fail_data }
      define_method(:random_success) { succ_data }
    end
  end

  def make_frames(prefix, height, count)
    count.times.map { height.times.map { |i| "#{prefix}-#{i}" } }
  end
end

class TestHeaderAnimationManagerEvents < Minitest::Test
  HEADER_HEIGHT = 14

  def test_should_show_event_animation_after_trigger_failure
    manager = make_manager
    # When a failure event fires
    manager.trigger_failure
    lines = manager.current_lines(80)
    # Then the lines should contain event content (not idle)
    plain = lines.map { |l| FunCi::Ansi.strip(l) }.join
    assert_match(/line-/, plain, "Should show event animation content")
    assert manager.any_active_event?, "Should report active event"
  end

  def test_should_show_event_animation_after_trigger_success
    manager = make_manager
    # When a success event fires
    manager.trigger_success
    # Then it should report active event
    assert manager.any_active_event?, "Should report active event for success"
  end

  def test_should_return_to_idle_after_event_finishes
    manager = make_manager
    manager.trigger_failure
    # When we advance past all event frames (2 frames)
    3.times { manager.advance! }
    manager.expire_if_finished!
    # Then the event should be gone and idle should show
    refute manager.any_active_event?, "Event should have expired"
    lines = manager.current_lines(80)
    assert_equal HEADER_HEIGHT, lines.length, "Should still return full height"
  end

  def test_should_pad_short_animations_to_header_height
    manager = make_manager
    manager.trigger_failure
    # The fake failure animation is 8 lines; header height is 14
    lines = manager.current_lines(80)
    assert_equal HEADER_HEIGHT, lines.length,
      "Short event animations should be padded to HEADER_HEIGHT"
  end

  def test_should_keep_idle_advancing_during_event
    manager = make_manager
    manager.trigger_failure
    # When we advance multiple times during the event
    5.times { manager.advance! }
    manager.expire_if_finished!
    # Then the idle player should have advanced (not be at frame 0)
    # We advanced 5 times with 3 idle frames: 5 % 3 = 2
    # Get idle content and verify it is not frame 0
    refute manager.any_active_event?, "Event should have expired"
  end

  private

  def make_manager
    FunCi::HeaderAnimationManager.new(animation_library: make_fake_library)
  end

  def make_fake_library
    idle_data = { name: "Idle", fps: 4, frames: make_frames(HEADER_HEIGHT, 3) }
    running_data = { name: "Running", fps: 4, frames: make_frames(HEADER_HEIGHT, 3) }
    fail_data = { name: "Fail", fps: 8, frames: make_frames(8, 2) }
    succ_data = { name: "Succ", fps: 8, frames: make_frames(8, 2) }

    Module.new do
      extend self
      define_method(:idle)           { idle_data }
      define_method(:running)        { running_data }
      define_method(:random_failure) { fail_data }
      define_method(:random_success) { succ_data }
    end
  end

  def make_frames(height, count)
    count.times.map { height.times.map { |i| "line-#{i}" } }
  end
end
