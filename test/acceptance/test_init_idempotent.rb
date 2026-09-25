# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "fun_ci/setup/installer"
require "fun_ci/setup/hook_writer"
require "tmpdir"
require "stringio"

class TestInitEverythingIdempotent < Minitest::Test
  FOREIGN_HOOK = "#!/bin/sh\n# husky managed hook\nnpx lint-staged\n"

  def setup
    @dir = Dir.mktmpdir("fun-ci-idempotent-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_succeed_when_everything_is_run_twice
    File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\n")
    system("git", "init", "--quiet", @dir)
    assert_equal 0, init_everything, "First run should succeed"
    assert_equal 0, init_everything, "Second run should succeed (idempotent)"
  end

  def test_should_skip_init_with_message_when_fun_ci_already_exists
    File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\n")
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    exit_code = FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)
    assert_equal 0, exit_code, "Should return 0 when skipping"
    assert_match(/already exists/i, @stdout.string, "Should explain the skip")
  end

  def test_should_skip_hook_with_message_when_foreign_hook_exists
    system("git", "init", "--quiet", @dir)
    write_foreign_pre_commit_hook
    exit_code = FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: "pre-commit", stdout: @stdout)
    assert_equal 0, exit_code, "Should return 0 when skipping foreign hook"
    assert_match(/already exists/i, @stdout.string, "Should mention existing hook")
  end

  private

  def init_everything
    Dir.chdir(@dir) { FunCi::Cli.run(["init", "--everything"], stdout: StringIO.new, stderr: StringIO.new) }
  end

  def write_foreign_pre_commit_hook
    hook_path = File.join(@dir, ".git", "hooks", "pre-commit")
    FileUtils.mkdir_p(File.dirname(hook_path))
    File.write(hook_path, FOREIGN_HOOK)
    File.chmod(0o755, hook_path)
  end
end
