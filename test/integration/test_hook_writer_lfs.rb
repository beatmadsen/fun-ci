# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_writer"
require "fun_ci/setup/lfs_hook"
require "tmpdir"
require "stringio"

# In a Git LFS repository, `git lfs install` has written post-commit and
# pre-push already. Leaving them alone, as with any other tool's, would test
# no commit; fun-ci writes its own in their place, which runs git-lfs's too
# (AT-1.13).
class TestHookWriterLfs < Minitest::Test
  STOCK_POST_COMMIT = <<~SH
    #!/bin/sh
    command -v git-lfs >/dev/null 2>&1 || { printf >&2 "\\n%s\\n\\n" "This repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting the 'post-commit' file in the hooks directory (set by 'core.hookspath'; usually '.git/hooks')."; exit 2; }
    git lfs post-commit "$@"
  SH

  def setup
    @hooks_dir = File.join(Dir.mktmpdir("lfs-hooks"), "hooks")
    FileUtils.mkdir_p(@hooks_dir)
    @stdout = StringIO.new
  end

  def teardown = FileUtils.rm_rf(File.dirname(@hooks_dir))

  def test_should_write_its_hook_that_runs_git_lfs_s_in_place_of_git_lfs_s
    install_over(STOCK_POST_COMMIT)

    assert_equal FunCi::Setup::LfsHook.script("post-commit"), File.read(hook_path)
  end

  def test_should_say_its_hook_runs_git_lfs_s_too
    install_over(STOCK_POST_COMMIT)

    assert_equal "Installed post-commit hook, which runs git-lfs's too.\n", @stdout.string
  end

  # As when fun-ci's hook changes and `fun-ci install-hooks` runs again.
  def test_should_keep_running_git_lfs_s_when_it_writes_its_hook_again
    install_over(FunCi::Setup::LfsHook.script("post-commit").sub("fun-ci trigger", "fun-ci old-trigger"))

    assert_equal FunCi::Setup::LfsHook.script("post-commit"), File.read(hook_path)
  end

  def test_should_leave_a_hook_that_does_more_than_git_lfs_s_alone
    install_over("#{STOCK_POST_COMMIT}npx lint-staged\n")

    assert_equal "#{STOCK_POST_COMMIT}npx lint-staged\n", File.read(hook_path)
  end

  private

  def hook_path = File.join(@hooks_dir, "post-commit")

  def install_over(content)
    File.write(hook_path, content)
    FunCi::Setup::HookWriter.run(hooks_dir: @hooks_dir, hook_type: "post-commit", stdout: @stdout)
  end
end
