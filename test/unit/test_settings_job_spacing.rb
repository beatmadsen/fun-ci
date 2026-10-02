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

  private

  def settings(text) = FunCi::Setup::Settings.new(text)
end
