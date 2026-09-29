# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/fake_stage_dir"
require "fun_ci/evidence/about_stage"
require "fun_ci/evidence/sources"
require "fun_ci/evidence/outcome"

# What a project's command is told about the stage (contract/evidence/):
# `fun-ci extract` has a saved output and no run, so no start.
class TestAboutStage < Minitest::Test
  OUTCOME = FunCi::Evidence::Outcome.new(state: "failed", exit_status: 1)

  def test_should_say_when_the_stage_started_in_utc_to_the_millisecond
    started = Time.new(2026, 9, 27, 16, 2, 11.402r, "+02:00")

    assert_equal "2026-09-27T14:02:11.402Z", about(started: started).started_at
  end

  def test_should_leave_the_start_and_duration_unknown_for_a_stage_with_no_start
    unknown = about

    assert_equal [nil, nil], [unknown.started_at, unknown.seconds]
  end

  private

  def about(**given)
    sources = FunCi::Evidence::Sources.new(stage: "fast", worktree: "/slot-0", stage_dir: FakeStageDir.new,
                                           environment: {}, **given)
    FunCi::Evidence::AboutStage.of(sources, OUTCOME, "boom\n")
  end
end
