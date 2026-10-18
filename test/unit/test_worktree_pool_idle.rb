# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/worktree_pool"

# When a slot counts as cold for having gone untaken: over a day.
class TestWorktreePoolIdle < Minitest::Test
  NOW = Time.utc(2026, 10, 19, 12)
  DAY = FunCi::Pipeline::WorktreePool::IDLE_SECONDS

  def test_should_count_a_slot_taken_over_a_day_ago_as_idle
    assert FunCi::Pipeline::WorktreePool.idle?(NOW - DAY - 1, now: NOW)
  end

  def test_should_not_count_a_slot_taken_a_day_ago_to_the_second_as_idle
    refute FunCi::Pipeline::WorktreePool.idle?(NOW - DAY, now: NOW)
  end
end
