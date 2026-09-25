# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/row_formatter"
require "fun_ci/tui/ansi"

class TestRowFormatterPassedRun < Minitest::Test
  PASSED_STAGES = [
    { stage: "lint", status: "completed", duration: 0.1 },
    { stage: "build", status: "completed", duration: 0.3 },
    { stage: "fast", status: "completed", duration: 1.8 },
    { stage: "slow", status: "completed", duration: 47.0 }
  ].freeze

  def test_should_show_commit_and_branch
    result = plain_row(make_passed_run)
    assert_match(/a3f7c01/, result, "Should show commit hash")
    assert_match(/main/, result, "Should show branch name")
  end

  def test_should_truncate_commit_hash_to_7_characters
    run_data = make_passed_run
    run_data[:commit_hash] = "a3f7c01deadbeef1234567890abcdef1234567890"
    result = plain_row(run_data)
    assert_match(/a3f7c01/, result, "Should show short hash")
    refute_match(/deadbeef/, result, "Should not show full hash beyond 7 chars")
  end

  def test_should_show_stage_times
    result = plain_row(make_passed_run)
    assert_match(/Lint 0\.1s/, result, "Should show lint time")
    assert_match(/Build 0\.3s/, result, "Should show build time")
    assert_match(/Fast 1\.8s/, result, "Should show fast time")
    assert_match(/Slow 47s/, result, "Should show slow time")
  end

  def test_should_show_passed_status
    assert_match(/PASSED/, plain_row(make_passed_run))
  end

  def test_should_show_relative_time
    run_data = make_passed_run
    result = plain_row(run_data, now: Time.parse(run_data[:updated_at]) + 120)
    assert_match(/2m ago/, result)
  end

  def test_should_color_stage_times_green
    result = FunCi::Tui::RowFormatter.format(make_passed_run)
    assert_match(/\e\[32m.*Build/, result, "Stage times should be green")
  end

  def test_should_color_passed_status_bold_green
    result = FunCi::Tui::RowFormatter.format(make_passed_run)
    assert_match(/\e\[1;32m.*PASSED/, result, "PASSED should be bold green")
  end

  private

  def plain_row(run_data, **)
    FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data, **))
  end

  def make_passed_run
    {
      commit_hash: "a3f7c01", branch: "main", status: "completed",
      updated_at: Time.now.utc.iso8601, stages: PASSED_STAGES
    }
  end
end
