# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_writer"
require "tmpdir"
require "stringio"

class TestHookWriterHappyPath < Minitest::Test
  def test_should_write_pre_commit_hook_script
    # Given a project with .git/hooks/
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new

      # When we install a pre-commit hook
      FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then the hook file should exist
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      assert File.exist?(hook_path), "pre-commit hook should exist"
    end
  end

  def test_should_make_hook_script_executable
    # Given a project with .git/hooks/
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new

      # When we install a pre-commit hook
      FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then the hook file should be executable
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      assert File.executable?(hook_path), "Hook should be executable"
    end
  end

  def test_should_include_marker_comment_in_generated_hook
    # Given a project with .git/hooks/
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new

      # When we install a pre-commit hook
      FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then the hook should include the marker comment
      content = File.read(File.join(dir, ".git", "hooks", "pre-commit"))
      assert_match(/# fun-ci-managed-hook/, content, "Should include marker")
    end
  end

  def test_should_include_trigger_invocation_with_error_handling
    # Given a project with .git/hooks/
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new

      # When we install a pre-commit hook
      FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then the hook should call fun-ci trigger with empty-repo fallback
      content = File.read(File.join(dir, ".git", "hooks", "pre-commit"))
      assert_match(/fun-ci.*trigger/, content, "Should call fun-ci trigger")
      assert_match(%r{2>/dev/null}, content, "Should handle empty repo gracefully")
    end
  end

  def test_should_create_hooks_directory_if_missing
    # Given a project with .git/ but no hooks/ subdirectory
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git"))
      stdout = StringIO.new

      # When we install a pre-commit hook
      FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then the hooks directory and hook file should exist
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      assert File.exist?(hook_path), "Hook should exist even when hooks/ was missing"
    end
  end
end

class TestHookWriterGuards < Minitest::Test
  def test_should_reject_unknown_hook_type
    # Given a project with .git/hooks/
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new

      # When we try to install an unknown hook type
      exit_code = FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "post-merge", stdout: stdout)

      # Then it should refuse
      assert_equal 1, exit_code, "Should reject unknown hook type"
    end
  end

  def test_should_skip_with_success_when_existing_hook_has_no_marker
    # Given a project with an existing hook from another tool
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      File.write(hook_path, "#!/bin/sh\n# husky managed hook\nnpx lint-staged\n")
      File.chmod(0o755, hook_path)
      stdout = StringIO.new

      # When we try to install our hook
      exit_code = FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then it should skip and return success
      assert_equal 0, exit_code, "Should return 0 when skipping foreign hook"
      assert_match(/already exists/i, stdout.string, "Should explain the skip")
    end
  end

  def test_should_overwrite_when_existing_hook_has_marker
    # Given a project with an existing fun-ci hook
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      File.write(hook_path, "#!/bin/sh\n# fun-ci-managed-hook\nold-fun-ci-trigger\n")
      File.chmod(0o755, hook_path)
      stdout = StringIO.new

      # When we install our hook
      exit_code = FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then it should succeed and overwrite
      assert_equal 0, exit_code, "Should overwrite our own hook"
      content = File.read(hook_path)
      assert_match(/fun-ci trigger/, content, "Should have updated content")
    end
  end

  def test_should_refuse_when_not_in_a_git_repo
    # Given a directory without .git/
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      stdout = StringIO.new

      # When we try to install a hook
      exit_code = FunCi::Setup::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then it should refuse
      assert_equal 1, exit_code, "Should refuse without .git"
      assert_match(/\.git/i, stdout.string, "Should mention missing .git")
    end
  end
end
