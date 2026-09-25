# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_script"

# The script fun-ci writes into a git hook.
class TestHookScript < Minitest::Test
  def test_should_hand_a_pre_commit_to_the_background
    assert_includes FunCi::Setup::HookScript.for("pre-commit"), %(fun-ci trigger --no-validate "$COMMIT" "$BRANCH")
  end

  def test_should_run_the_full_pipeline_before_a_push
    assert_includes FunCi::Setup::HookScript.for("pre-push"), %(fun-ci trigger "$COMMIT" "$BRANCH")
  end

  def test_should_mark_the_script_as_fun_ci_s_own
    assert_includes FunCi::Setup::HookScript.for("pre-push"), "# fun-ci-managed-hook"
  end

  def test_should_fall_back_to_the_null_sha_in_a_repository_without_commits
    assert_includes FunCi::Setup::HookScript.for("pre-push"),
                    %(COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "#{"0" * 40}"))
  end

  def test_should_recognise_a_script_it_wrote
    assert FunCi::Setup::HookScript.managed?(FunCi::Setup::HookScript.for("pre-push"))
  end

  def test_should_not_claim_a_script_another_tool_wrote
    refute FunCi::Setup::HookScript.managed?("#!/bin/sh\n# husky managed hook\nnpx lint-staged\n")
  end

  def test_should_know_the_hooks_it_can_write
    assert_equal %w[pre-commit pre-push], FunCi::Setup::HookScript.types
  end
end
