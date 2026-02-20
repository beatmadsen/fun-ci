# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/hook_writer"
require "tmpdir"
require "stringio"

class TestInstallHookCli < Minitest::Test
  def test_should_install_hook_and_report_success
    # Given a git repository
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      system("git", "init", "--quiet", dir)
      stdout = StringIO.new

      # When we install a pre-commit hook
      exit_code = FunCi::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then it should succeed
      assert_equal 0, exit_code, "Should return success"

      # And the hook file should exist and be executable
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      assert File.exist?(hook_path), "Hook file should exist"
      assert File.executable?(hook_path), "Hook file should be executable"

      # And the hook should call fun-ci trigger with error handling
      content = File.read(hook_path)
      assert_match(/fun-ci.*trigger/, content, "Should call fun-ci trigger")
      assert_match(/# fun-ci-managed-hook/, content, "Should include marker")

      # And stdout should confirm installation
      assert_match(/pre-commit/, stdout.string, "Should mention hook type")
    end
  end

  def test_should_refuse_when_not_in_a_git_repo
    # Given a directory that is NOT a git repo
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      stdout = StringIO.new

      # When we try to install a hook
      exit_code = FunCi::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then it should refuse
      assert_equal 1, exit_code, "Should return failure"
      assert_match(/\.git/i, stdout.string, "Should mention missing .git")
    end
  end
end
