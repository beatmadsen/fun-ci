# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/row_formatter"
require "fun_ci/ansi"

class TestRowFormatterPassedRun < Minitest::Test
  def test_should_show_commit_and_branch
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then it should contain commit and branch
    assert_match(/a3f7c01/, result, "Should show commit hash")
    assert_match(/main/, result, "Should show branch name")
  end

  def test_should_show_stage_times
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then it should show all three stage times
    assert_match(/Build 0\.3s/, result, "Should show build time")
    assert_match(/Fast 1\.8s/, result, "Should show fast time")
    assert_match(/Slow 47s/, result, "Should show slow time")
  end

  def test_should_show_passed_status
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data))
    # Then it should show PASSED status
    assert_match(/PASSED/, result)
  end

  def test_should_show_relative_time
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it
    result = FunCi::Ansi.strip(FunCi::RowFormatter.format(run_data, now: Time.parse(run_data[:updated_at]) + 120))
    # Then it should show relative time
    assert_match(/2m ago/, result)
  end

  def test_should_color_stage_times_green
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it (with color)
    result = FunCi::RowFormatter.format(run_data)
    # Then it should contain green ANSI codes
    assert_match(/\e\[32m.*Build/, result, "Stage times should be green")
  end

  def test_should_color_passed_status_bold_green
    # Given a passed pipeline run
    run_data = make_passed_run
    # When we format it (with color)
    result = FunCi::RowFormatter.format(run_data)
    # Then status should be bold green
    assert_match(/\e\[1;32m.*PASSED/, result, "PASSED should be bold green")
  end

  private

  def make_passed_run
    now = Time.now.utc
    {
      commit_hash: "a3f7c01", branch: "main", status: "completed",
      updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.3 },
        { stage: "fast", status: "completed", duration: 1.8 },
        { stage: "slow", status: "completed", duration: 47.0 }
      ]
    }
  end
end
