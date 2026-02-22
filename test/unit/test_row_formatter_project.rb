# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/row_formatter"
require "fun_ci/tui/ansi"

# Inner BDD cycle: RowFormatter should display the project name
# extracted from the project_path (basename of the path).

class TestRowFormatterProjectName < Minitest::Test
  def test_should_show_project_name_when_project_path_is_present
    # Given a completed run with a project_path
    run_data = make_run_with_project("/home/user/alpha-app")
    # When we format it
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    # Then the output should include the project basename
    assert_match(/alpha-app/, result, "Should show project name from path")
  end

  def test_should_omit_project_name_when_project_path_is_nil
    # Given a completed run without a project_path
    run_data = make_run_without_project
    # When we format it
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    # Then it should still show commit and branch (no crash)
    assert_match(/a3f7c01/, result, "Should show commit hash")
    assert_match(/main/, result, "Should show branch name")
  end

  def test_should_color_project_name_not_dim
    # Given a completed run with a project_path
    run_data = make_run_with_project("/home/user/alpha-app")
    # When we format it with color
    result = FunCi::Tui::RowFormatter.format(run_data)
    # Then the project name should use a color, not dim
    refute_match(/\e\[2m.*alpha-app/, result, "Project name should not be dim")
    assert_match(/\e\[\d+m.*alpha-app/, result, "Project name should have a color code")
  end

  def test_should_assign_same_color_to_same_project_name
    # Given two runs with the same project path
    run_a = make_run_with_project("/home/user/alpha-app")
    run_b = make_run_with_project("/other/path/alpha-app")
    # When we format both
    result_a = FunCi::Tui::RowFormatter.format(run_a)
    result_b = FunCi::Tui::RowFormatter.format(run_b)
    # Then both should use the same color for the same basename
    color_a = result_a[/(\e\[\d+m).*alpha-app/, 1]
    color_b = result_b[/(\e\[\d+m).*alpha-app/, 1]
    assert_equal color_a, color_b, "Same project name should get same color"
  end

  private

  def make_run_with_project(project_path)
    now = Time.now.utc
    {
      commit_hash: "a3f7c01", branch: "main", status: "completed",
      project_path: project_path, updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.3 },
        { stage: "fast", status: "completed", duration: 1.8 },
        { stage: "slow", status: "completed", duration: 47.0 }
      ]
    }
  end

  def make_run_without_project
    now = Time.now.utc
    {
      commit_hash: "a3f7c01", branch: "main", status: "completed",
      project_path: nil, updated_at: now.iso8601,
      stages: [
        { stage: "build", status: "completed", duration: 0.3 },
        { stage: "fast", status: "completed", duration: 1.8 },
        { stage: "slow", status: "completed", duration: 47.0 }
      ]
    }
  end
end
