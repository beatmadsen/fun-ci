# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/lfs_hook"

# git-lfs's own hooks, as `git lfs install` writes them, and the hook fun-ci
# writes in their place, which runs git-lfs's too. What git and git-lfs make
# of it is pinned with real git in test_git_runs_lfs_hooks.rb.
class TestLfsHook < Minitest::Test
  # As git-lfs 3.7.1 writes it; older ones word the message differently.
  STOCK_PRE_PUSH = <<~SH
    #!/bin/sh
    command -v git-lfs >/dev/null 2>&1 || { printf >&2 "\\n%s\\n\\n" "This repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting the 'pre-push' file in the hooks directory (set by 'core.hookspath'; usually '.git/hooks')."; exit 2; }
    git lfs pre-push "$@"
  SH
  OLDER_POST_COMMIT = <<~SH
    #!/bin/sh
    command -v git-lfs >/dev/null 2>&1 || { echo >&2 "\\nThis repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting .git/hooks/post-commit.\\n"; exit 2; }
    git lfs post-commit "$@"
  SH

  def test_should_recognise_the_hook_git_lfs_writes
    assert FunCi::Setup::LfsHook.stock?(STOCK_PRE_PUSH, "pre-push")
  end

  def test_should_recognise_the_hook_an_older_git_lfs_writes
    assert FunCi::Setup::LfsHook.stock?(OLDER_POST_COMMIT, "post-commit")
  end

  def test_should_not_take_git_lfs_s_hook_of_another_type_for_this_one
    refute FunCi::Setup::LfsHook.stock?(STOCK_PRE_PUSH, "post-commit")
  end

  # A hook someone added to is theirs: replacing it would lose what they added.
  def test_should_not_take_a_hook_that_does_more_than_git_lfs_s_for_git_lfs_s
    refute FunCi::Setup::LfsHook.stock?("#{STOCK_PRE_PUSH}npx lint-staged\n", "pre-push")
  end

  def test_should_see_that_fun_ci_s_hook_runs_git_lfs_s
    assert FunCi::Setup::LfsHook.runs_lfs?(FunCi::Setup::LfsHook.script("pre-push"), "pre-push")
  end

  def test_should_see_that_fun_ci_s_own_hook_runs_no_git_lfs
    refute FunCi::Setup::LfsHook.runs_lfs?(FunCi::Setup::HookScript.for("pre-push"), "pre-push")
  end

  def test_should_mark_the_hook_as_fun_ci_s_own
    assert FunCi::Setup::HookScript.managed?(FunCi::Setup::LfsHook.script("post-commit"))
  end

  def test_should_hand_each_new_commit_to_the_background_before_git_lfs_s_post_commit
    script = FunCi::Setup::LfsHook.script("post-commit")

    assert_operator script.index("fun-ci trigger --background"), :<, script.index(%(git lfs post-commit "$@"))
  end

  # git sends the ref list once; fun-ci reads it, and git-lfs reads it after.
  def test_should_give_git_lfs_the_ref_list_fun_ci_read
    assert_includes FunCi::Setup::LfsHook.script("pre-push"), %(git lfs pre-push "$@" < "$refs")
  end

  # A push fun-ci stops sends no LFS objects for it.
  def test_should_stop_the_push_before_git_lfs_when_a_verdict_is_not_passed
    assert_includes FunCi::Setup::LfsHook.script("pre-push"), %(fun_ci < "$refs" || exit 1)
  end
end
