# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_script"

# The script fun-ci writes into a git hook.
class TestHookScript < Minitest::Test
  # After the commit, so the commit it tests is the one just made.
  def test_should_hand_each_new_commit_to_the_background
    assert_includes FunCi::Setup::HookScript.for("post-commit"), %(fun-ci trigger --background "$COMMIT" "$BRANCH")
  end

  # Git names on stdin each commit a push sends; a deleted ref sends the null SHA.
  def test_should_wait_for_the_fast_verdict_of_each_commit_pushed
    assert_includes FunCi::Setup::HookScript.for("pre-push"), %(fun-ci wait "$local_sha" --need fast)
  end

  def test_should_read_the_commits_pushed_from_git
    assert_includes FunCi::Setup::HookScript.for("pre-push"), "while read -r local_ref local_sha remote_ref remote_sha"
  end

  # 5: no run, in a project not set up for fun-ci, which pushes without CI as before.
  def test_should_let_the_push_through_only_when_every_wait_passed_or_found_fun_ci_not_set_up
    assert_includes FunCi::Setup::HookScript.for("pre-push"), %([ "$code" -eq 0 ] || [ "$code" -eq 5 ] || status=1)
  end

  def test_should_mark_the_script_as_fun_ci_s_own
    assert_includes FunCi::Setup::HookScript.for("pre-push"), "# fun-ci-managed-hook"
  end

  def test_should_fall_back_to_the_null_sha_in_a_repository_without_commits
    assert_includes FunCi::Setup::HookScript.for("post-commit"),
                    %(COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "#{"0" * 40}"))
  end

  def test_should_recognise_a_script_it_wrote
    assert FunCi::Setup::HookScript.managed?(FunCi::Setup::HookScript.for("pre-push"))
  end

  def test_should_not_claim_a_script_another_tool_wrote
    refute FunCi::Setup::HookScript.managed?("#!/bin/sh\n# husky managed hook\nnpx lint-staged\n")
  end

  def test_should_know_the_hooks_it_can_write
    assert_equal %w[post-commit pre-push], FunCi::Setup::HookScript.types
  end
end
