# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/row_formatter"
require "fun_ci/tui/ansi"

class TestRowFormatterProjectName < Minitest::Test
  COMPLETED_STAGES = [
    { stage: "build", status: "completed", duration: 0.3 },
    { stage: "fast", status: "completed", duration: 1.8 },
    { stage: "slow", status: "completed", duration: 47.0 }
  ].freeze

  def test_should_show_project_name_when_project_path_is_present
    run_data = make_run_with_project("/home/user/alpha-app")
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/alpha-app/, result, "Should show project name from path")
  end

  def test_should_omit_project_name_when_project_path_is_nil
    run_data = make_run_without_project
    result = FunCi::Tui::Ansi.strip(FunCi::Tui::RowFormatter.format(run_data))
    assert_match(/a3f7c01/, result, "Should show commit hash")
    assert_match(/main/, result, "Should show branch name")
  end

  def test_should_color_project_name_not_dim
    run_data = make_run_with_project("/home/user/alpha-app")
    result = FunCi::Tui::RowFormatter.format(run_data)
    refute_match(/\e\[2m.*alpha-app/, result, "Project name should not be dim")
    assert_match(/\e\[\d+m.*alpha-app/, result, "Project name should have a color code")
  end

  def test_should_assign_same_color_to_same_project_name
    run_a = make_run_with_project("/home/user/alpha-app")
    run_b = make_run_with_project("/other/path/alpha-app")
    result_a = FunCi::Tui::RowFormatter.format(run_a)
    result_b = FunCi::Tui::RowFormatter.format(run_b)
    color_a = result_a[/(\e\[\d+m).*alpha-app/, 1]
    color_b = result_b[/(\e\[\d+m).*alpha-app/, 1]
    assert_equal color_a, color_b, "Same project name should get same color"
  end

  # The palette index is CRC-32 of the basename (renderer-protocol.md), so the
  # colour survives a restart; String#hash is seeded per process.
  def test_project_colour_depends_only_on_the_project_name
    colours = %w[fun-ci agent-tome].map do |name|
      FunCi::Tui::RowFormatter.format(make_run_with_project("/src/#{name}"))[/\e\[(\d+)m#{name}/, 1]
    end

    assert_equal %w[35 92], colours
  end

  private

  def make_run_with_project(project_path)
    {
      commit_hash: "a3f7c01", branch: "main", status: "completed",
      project_path: project_path, updated_at: Time.now.utc.iso8601,
      stages: COMPLETED_STAGES
    }
  end

  def make_run_without_project
    make_run_with_project(nil)
  end
end
