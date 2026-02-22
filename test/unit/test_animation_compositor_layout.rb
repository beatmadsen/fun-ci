# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_compositor"

class TestAnimationCompositorStageText < Minitest::Test
  def test_stage_text_for_completed_stage
    run = make_run("completed", 0.1)
    text = FunCi::Tui::AnimationCompositor.stage_text_for(run, "lint")
    assert_equal "Lint 0.1s", text
  end

  def test_stage_text_for_failed_stage
    run = make_run("failed", 6.2)
    text = FunCi::Tui::AnimationCompositor.stage_text_for(run, "lint")
    assert_equal "Lint FAIL 6.2s", text
  end

  def test_stage_text_for_timed_out_stage
    run = make_run("timed_out", 10.0)
    text = FunCi::Tui::AnimationCompositor.stage_text_for(run, "lint")
    assert_equal "Lint TIMEOUT 10s", text
  end

  def test_stage_text_for_pending_stage
    run = make_run("pending", nil)
    text = FunCi::Tui::AnimationCompositor.stage_text_for(run, "lint")
    assert_equal "Lint --", text
  end

  def test_stage_text_for_missing_stage_returns_nil
    run = { id: 1, stages: [] }
    assert_nil FunCi::Tui::AnimationCompositor.stage_text_for(run, "lint")
  end

  private

  def make_run(status, duration)
    { id: 1, commit_hash: "a3f7c01", branch: "main",
      stages: [{ stage: "lint", status: status, duration: duration }] }
  end
end

class TestAnimationCompositorStageCol < Minitest::Test
  def test_stage_col_for_first_stage
    run = make_multi_stage_run
    col = FunCi::Tui::AnimationCompositor.stage_col_for(run, "lint")
    # 2 (indent) + 7 (hash) + 2 (gap) + 4 (main) + 2 (gap) = 17, +1 = 18
    assert_equal 18, col
  end

  def test_stage_col_for_second_stage
    run = make_multi_stage_run
    col = FunCi::Tui::AnimationCompositor.stage_col_for(run, "build")
    # 18 (lint start) + "Lint 0.1s".length(9) + 2 (gap) = 29
    assert_equal 29, col
  end

  def test_stage_col_for_missing_stage_returns_nil
    run = make_multi_stage_run
    assert_nil FunCi::Tui::AnimationCompositor.stage_col_for(run, "slow")
  end

  def test_stage_col_accounts_for_long_branch_name
    run = make_multi_stage_run
    run[:branch] = "feature/very-long-branch"
    col = FunCi::Tui::AnimationCompositor.stage_col_for(run, "lint")
    # 2 + 7 + 2 + 24 + 2 = 37, +1 = 38
    assert_equal 38, col
  end

  def test_stage_col_accounts_for_project_path
    run = make_multi_stage_run
    run[:project_path] = "/home/user/my-project"
    col = FunCi::Tui::AnimationCompositor.stage_col_for(run, "lint")
    # 2 + 7 + 2 + 4 + "  my-project".length(12) + 2 = 29, +1 = 30
    assert_equal 30, col
  end

  private

  def make_multi_stage_run
    { id: 1, commit_hash: "a3f7c01", branch: "main", project_path: nil,
      stages: [
        { stage: "lint", status: "completed", duration: 0.1 },
        { stage: "build", status: "completed", duration: 0.3 }
      ] }
  end
end
