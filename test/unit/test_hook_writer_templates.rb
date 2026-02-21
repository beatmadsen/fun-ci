# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/hook_writer"
require "tmpdir"
require "stringio"

class TestHookWriterPreCommitTemplate < Minitest::Test
  def test_pre_commit_hook_should_include_no_validate_flag
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new
      FunCi::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)
      content = File.read(File.join(dir, ".git", "hooks", "pre-commit"))
      assert_match(/--no-validate/, content,
        "Pre-commit hook should include --no-validate flag")
    end
  end

  def test_pre_commit_hook_should_use_unified_command_name
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new
      FunCi::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)
      content = File.read(File.join(dir, ".git", "hooks", "pre-commit"))
      assert_match(/fun-ci trigger/, content,
        "Pre-commit hook should use 'fun-ci trigger' command")
    end
  end
end

class TestHookWriterPrePushTemplate < Minitest::Test
  def test_pre_push_hook_should_not_include_no_validate_flag
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new
      FunCi::HookWriter.run(project_root: dir, hook_type: "pre-push", stdout: stdout)
      content = File.read(File.join(dir, ".git", "hooks", "pre-push"))
      refute_match(/--no-validate/, content,
        "Pre-push hook should NOT include --no-validate flag")
    end
  end

  def test_pre_push_hook_should_use_unified_command_name
    Dir.mktmpdir("fun-ci-hook-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
      stdout = StringIO.new
      FunCi::HookWriter.run(project_root: dir, hook_type: "pre-push", stdout: stdout)
      content = File.read(File.join(dir, ".git", "hooks", "pre-push"))
      assert_match(/fun-ci trigger/, content,
        "Pre-push hook should use 'fun-ci trigger' command")
    end
  end
end
