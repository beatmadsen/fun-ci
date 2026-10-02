# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/settings"

# How far apart the jobs a commit starts begin, from .fun-ci/config's
# `job_spacing` (design.md, Daily and weekly jobs); like the trunk's
# settings, one that is wrong takes the default and stops nothing.
class TestSettingsJobSpacing < Minitest::Test
  def test_should_start_jobs_ten_minutes_apart_when_nothing_says_otherwise
    assert_equal 600, settings(nil).job_spacing
  end

  def test_should_start_jobs_as_far_apart_as_asked
    assert_equal 3600, settings("job_spacing: 1h\n").job_spacing
  end

  def test_should_start_jobs_all_at_once_when_told_zero
    assert_equal 0, settings("job_spacing: 0\n").job_spacing
  end

  def test_should_start_jobs_ten_minutes_apart_when_the_spacing_given_is_unreadable
    assert_equal 600, settings("job_spacing: often\n").job_spacing
  end

  # Unlike the trunk's, since a job's turns are its whole point (AT-13.28).
  def test_should_name_a_spacing_it_cannot_read
    assert_equal [".fun-ci/config: job_spacing must be seconds, or a number with s, m or h, not \"10 minutes\""],
                 settings("job_spacing: 10 minutes\n").errors
  end

  def test_should_keep_the_worktree_slots_asked_for_beside_a_spacing_it_cannot_read
    assert_equal 3, settings("worktree_slots: 3\njob_spacing: soon\n").worktree_slots
  end

  def test_should_find_nothing_wrong_with_a_spacing_of_none
    assert_empty settings("job_spacing: 0\n").errors
  end

  private

  def settings(text) = FunCi::Setup::Settings.new(text)
end
