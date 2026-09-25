# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/hook_writer"
require "tmpdir"
require "stringio"

module HookWriterProject
  def setup
    @dir = Dir.mktmpdir("fun-ci-hook-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def make_hooks_dir
    FileUtils.mkdir_p(File.join(@dir, ".git", "hooks"))
  end

  def hook_path
    File.join(@dir, ".git", "hooks", "pre-commit")
  end

  def existing_hook(content)
    make_hooks_dir
    File.write(hook_path, content)
    File.chmod(0o755, hook_path)
  end

  def install(hook_type = "pre-commit")
    FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: hook_type, stdout: @stdout)
  end
end

class TestHookWriterHappyPath < Minitest::Test
  include HookWriterProject

  def test_should_write_pre_commit_hook_script
    make_hooks_dir
    install
    assert File.exist?(hook_path), "pre-commit hook should exist"
  end

  def test_should_make_hook_script_executable
    make_hooks_dir
    install
    assert File.executable?(hook_path), "Hook should be executable"
  end

  def test_should_include_marker_comment_in_generated_hook
    make_hooks_dir
    install
    assert_match(/# fun-ci-managed-hook/, File.read(hook_path), "Should include marker")
  end

  def test_should_include_trigger_invocation_with_error_handling
    make_hooks_dir
    install
    content = File.read(hook_path)
    assert_match(/fun-ci.*trigger/, content, "Should call fun-ci trigger")
    assert_match(%r{2>/dev/null}, content, "Should handle empty repo gracefully")
  end

  def test_should_create_hooks_directory_if_missing
    FileUtils.mkdir_p(File.join(@dir, ".git"))
    install
    assert File.exist?(hook_path), "Hook should exist even when hooks/ was missing"
  end
end

class TestHookWriterGuards < Minitest::Test
  include HookWriterProject

  def test_should_reject_unknown_hook_type
    make_hooks_dir
    assert_equal 1, install("post-merge"), "Should reject unknown hook type"
  end

  def test_should_skip_with_success_when_existing_hook_has_no_marker
    existing_hook("#!/bin/sh\n# husky managed hook\nnpx lint-staged\n")
    assert_equal 0, install, "Should return 0 when skipping foreign hook"
    assert_match(/already exists/i, @stdout.string, "Should explain the skip")
  end

  def test_should_overwrite_when_existing_hook_has_marker
    existing_hook("#!/bin/sh\n# fun-ci-managed-hook\nold-fun-ci-trigger\n")
    assert_equal 0, install, "Should overwrite our own hook"
    assert_match(/fun-ci trigger/, File.read(hook_path), "Should have updated content")
  end

  def test_should_refuse_when_not_in_a_git_repo
    assert_equal 1, install, "Should refuse without .git"
    assert_match(/\.git/i, @stdout.string, "Should mention missing .git")
  end
end
