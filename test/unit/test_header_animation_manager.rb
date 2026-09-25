# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/header_animation_manager"
require "fun_ci/tui/ansi"

# Idle and running frames fill the header; event frames are shorter (8 lines).
# Every line names its animation and frame, e.g. "idle-f2-0".
module FakeHeaderAnimations
  HEADER_HEIGHT = 14

  def make_manager
    FunCi::Tui::HeaderAnimationManager.new(animation_library: fake_library)
  end

  def plain_header(manager)
    manager.current_lines(80).map { |l| FunCi::Tui::Ansi.strip(l) }.join
  end

  private

  def fake_library
    animations = { idle: animation("idle", HEADER_HEIGHT, 3), running: animation("running", HEADER_HEIGHT, 3),
                   random_failure: animation("event", 8, 2), random_success: animation("event", 8, 2) }
    Struct.new(*animations.keys).new(*animations.values)
  end

  def animation(prefix, height, count)
    { name: prefix, fps: 4, frames: count.times.map { |f| height.times.map { |i| "#{prefix}-f#{f}-#{i}" } } }
  end
end

class TestHeaderAnimationManagerIdle < Minitest::Test
  include FakeHeaderAnimations

  def test_should_show_idle_animation_by_default
    refute make_manager.current_lines(80).empty?, "Should show idle animation when no event is active"
  end

  def test_should_always_return_header_height_lines
    assert_equal HEADER_HEIGHT, make_manager.current_lines(80).length,
                 "Should pad output to HEADER_HEIGHT lines"
  end

  def test_should_not_report_active_event_during_idle
    refute make_manager.any_active_event?, "Idle animation should not count as active event"
  end
end

class TestHeaderAnimationManagerRunning < Minitest::Test
  include FakeHeaderAnimations

  def test_should_show_running_animation_when_started
    manager = make_manager
    manager.start_running
    assert_match(/running-/, plain_header(manager), "Should show running animation content")
  end

  def test_should_return_to_idle_when_running_stops
    manager = make_manager
    manager.start_running
    manager.stop_running
    assert_match(/idle-/, plain_header(manager), "Should return to idle after running stops")
  end

  def test_event_takes_priority_over_running
    manager = make_manager
    manager.start_running
    manager.trigger_failure
    assert_match(/event-/, plain_header(manager), "Event should take priority over running")
  end

  def test_should_return_to_running_after_event_expires
    manager = make_manager
    manager.start_running
    manager.trigger_failure
    3.times { manager.advance! }
    manager.expire_if_finished!
    assert_match(/running-/, plain_header(manager), "Should return to running after event expires")
  end

  def test_should_advance_running_player
    manager = make_manager
    manager.start_running
    manager.advance!
    assert_equal HEADER_HEIGHT, manager.current_lines(80).length
  end
end

class TestHeaderAnimationManagerEvents < Minitest::Test
  include FakeHeaderAnimations

  def test_should_show_event_animation_after_trigger_failure
    manager = make_manager
    manager.trigger_failure
    assert_match(/event-/, plain_header(manager), "Should show event animation content")
    assert manager.any_active_event?, "Should report active event"
  end

  def test_should_show_event_animation_after_trigger_success
    manager = make_manager
    manager.trigger_success
    assert manager.any_active_event?, "Should report active event for success"
  end

  def test_should_return_to_idle_after_event_finishes
    manager = make_manager
    manager.trigger_failure
    3.times { manager.advance! }
    manager.expire_if_finished!
    refute manager.any_active_event?, "Event should have expired"
    assert_equal HEADER_HEIGHT, manager.current_lines(80).length, "Should still return full height"
  end

  def test_should_pad_short_animations_to_header_height
    manager = make_manager
    manager.trigger_failure
    assert_equal HEADER_HEIGHT, manager.current_lines(80).length,
                 "Short event animations should be padded to HEADER_HEIGHT"
  end

  def test_should_keep_idle_advancing_during_event
    manager = make_manager
    manager.trigger_failure
    5.times { manager.advance! }
    manager.expire_if_finished!
    refute manager.any_active_event?, "Event should have expired"
    assert_match(/idle-f2-/, plain_header(manager), "Idle should be on frame 5 % 3 = 2 after the event")
  end
end
