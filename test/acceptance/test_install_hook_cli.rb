# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_writer"
require "tmpdir"
require "stringio"

class TestInstallHookCli < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-hook-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_install_hook_and_report_success
    system("git", "init", "--quiet", @dir)
    assert_equal 0, install_pre_commit_hook, "Should return success"
    assert_match(/pre-commit/, @stdout.string, "Should mention hook type")
  end

  def test_should_write_executable_hook_file
    system("git", "init", "--quiet", @dir)
    install_pre_commit_hook
    assert File.exist?(hook_path), "Hook file should exist"
    assert File.executable?(hook_path), "Hook file should be executable"
  end

  def test_should_write_managed_hook_that_calls_fun_ci_trigger
    system("git", "init", "--quiet", @dir)
    install_pre_commit_hook
    assert_match(/fun-ci.*trigger/, File.read(hook_path), "Should call fun-ci trigger")
    assert_match(/# fun-ci-managed-hook/, File.read(hook_path), "Should include marker")
  end

  def test_should_refuse_when_not_in_a_git_repo
    assert_equal 1, install_pre_commit_hook, "Should return failure"
    assert_match(/\.git/i, @stdout.string, "Should mention missing .git")
  end

  private

  def install_pre_commit_hook
    FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: "pre-commit", stdout: @stdout)
  end

  def hook_path
    File.join(@dir, ".git", "hooks", "pre-commit")
  end
end
