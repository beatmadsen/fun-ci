# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/jobs/wall_clock_wait"
require "fun_ci/jobs/site"

# How a job waits its turn (Jobs::Schedule), which can be hours: by the wall
# clock, a minute at a time, since sleep's own count stops while the machine
# sleeps, and a laptop asleep for part of the wait would start the job late.
class TestWallClockWait < Minitest::Test
  START = Time.utc(2026, 10, 2, 12)

  def test_should_wait_a_minute_at_a_time
    assert_equal [60, 60, 30], waits(150)
  end

  # Each minute asleep is ten more on the wall clock: the machine slept.
  def test_should_end_once_the_wall_clock_has_passed_the_wait_though_it_slept_less
    assert_equal [60, 60, 60], waits(1800, asleep: 540)
  end

  # A clock that never moves would otherwise keep it waiting for ever.
  def test_should_wait_no_more_minutes_than_the_wait_holds_and_one
    assert_equal 3, waits(120, still: true).size
  end

  private

  # The minutes it slept, on a clock that moves `asleep` seconds more than each
  # sleep, or not at all.
  def waits(seconds, asleep: 0, still: false)
    now = START
    slept = []
    advance = ->(chunk) { (slept << chunk) && (now += (still ? 0 : chunk + asleep)) }
    FunCi::Jobs::WallClockWait.new(clock: -> { now }, sleep: advance).call(seconds)
    slept
  end
end

# Where a job's run waits its turn, unless a test says otherwise.
class TestSiteWait < Minitest::Test
  def test_should_wait_by_the_wall_clock
    site = FunCi::Jobs::Site.new(project: "/p", db: nil, worktrees: nil, locks: nil, clock: -> { Time.now })

    assert_kind_of FunCi::Jobs::WallClockWait, site.wait
  end
end
