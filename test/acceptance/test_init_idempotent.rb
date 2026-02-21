# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "fun_ci/installer"
require "fun_ci/hook_writer"
require "tmpdir"
require "stringio"

class TestInitEverythingIdempotent < Minitest::Test
  def test_should_succeed_when_everything_is_run_twice
    # Given a Ruby project in a git repo where --everything has already been run
    Dir.mktmpdir("fun-ci-idempotent-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      system("git", "init", "--quiet", dir)

      first_stdout = StringIO.new
      first_exit = Dir.chdir(dir) do
        FunCi::Cli.run(["init", "--everything"], stdout: first_stdout, stderr: StringIO.new)
      end
      assert_equal 0, first_exit, "First run should succeed"

      # When we run --everything again
      second_stdout = StringIO.new
      second_exit = Dir.chdir(dir) do
        FunCi::Cli.run(["init", "--everything"], stdout: second_stdout, stderr: StringIO.new)
      end

      # Then the second run should also succeed (exit 0)
      assert_equal 0, second_exit, "Second run should succeed (idempotent)"
    end
  end

  def test_should_skip_init_with_message_when_fun_ci_already_exists
    # Given a Ruby project where .fun-ci/ already exists
    Dir.mktmpdir("fun-ci-idempotent-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      Dir.mkdir(File.join(dir, ".fun-ci"))
      stdout = StringIO.new

      # When we run init
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should skip with exit 0 and explain what happened
      assert_equal 0, exit_code, "Should return 0 when skipping"
      assert_match(/already exists/i, stdout.string, "Should explain the skip")
    end
  end

  def test_should_skip_hook_with_message_when_foreign_hook_exists
    # Given a git repo where a foreign pre-commit hook already exists
    Dir.mktmpdir("fun-ci-idempotent-test") do |dir|
      system("git", "init", "--quiet", dir)
      hook_path = File.join(dir, ".git", "hooks", "pre-commit")
      FileUtils.mkdir_p(File.dirname(hook_path))
      File.write(hook_path, "#!/bin/sh\n# husky managed hook\nnpx lint-staged\n")
      File.chmod(0o755, hook_path)
      stdout = StringIO.new

      # When we try to install our hook
      exit_code = FunCi::HookWriter.run(project_root: dir, hook_type: "pre-commit", stdout: stdout)

      # Then it should skip with exit 0 and explain what happened
      assert_equal 0, exit_code, "Should return 0 when skipping foreign hook"
      assert_match(/already exists/i, stdout.string, "Should mention existing hook")
    end
  end
end
