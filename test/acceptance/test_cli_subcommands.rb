# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "tmpdir"
require "stringio"

class TestCliInitSubcommand < Minitest::Test
  def test_init_creates_fun_ci_directory_through_cli
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["init"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 0, exit_code
      assert Dir.exist?(File.join(dir, ".fun-ci")), ".fun-ci/ should be created"
    end
  end

  def test_init_skips_when_fun_ci_already_exists
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      Dir.mkdir(File.join(dir, ".fun-ci"))
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["init"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 0, exit_code, "Should return 0 when skipping (idempotent)"
    end
  end
end

class TestCliInstallHooksBothByDefault < Minitest::Test
  def test_installs_both_hooks_when_no_type_given
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      system("git", "init", "--quiet", dir)
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["install-hooks"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 0, exit_code
      assert File.exist?(File.join(dir, ".git", "hooks", "pre-commit")), "pre-commit should exist"
      assert File.exist?(File.join(dir, ".git", "hooks", "pre-push")), "pre-push should exist"
    end
  end

  def test_installs_only_specified_hook_when_type_given
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      system("git", "init", "--quiet", dir)
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["install-hooks", "pre-push"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 0, exit_code
      assert File.exist?(File.join(dir, ".git", "hooks", "pre-push")), "pre-push should exist"
      refute File.exist?(File.join(dir, ".git", "hooks", "pre-commit")), "pre-commit should NOT exist"
    end
  end
end

class TestCliCheckSubcommand < Minitest::Test
  include FunCiTestProject

  def test_check_succeeds_for_configured_project
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      make_project_with_scripts(dir)
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["check"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 0, exit_code
    end
  end

  def test_check_fails_when_scripts_missing
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["check"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 1, exit_code
    end
  end
end

class TestCliInitEverything < Minitest::Test
  def test_everything_runs_init_hooks_and_check
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      system("git", "init", "--quiet", dir)
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["init", "--everything"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 0, exit_code
      assert Dir.exist?(File.join(dir, ".fun-ci")), ".fun-ci/ should be created"
      assert File.exist?(File.join(dir, ".git", "hooks", "pre-commit")), "pre-commit hook"
      assert File.exist?(File.join(dir, ".git", "hooks", "pre-push")), "pre-push hook"
    end
  end

  def test_everything_stops_when_init_fails
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      system("git", "init", "--quiet", dir)
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["init", "--everything"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 1, exit_code
      refute File.exist?(File.join(dir, ".git", "hooks", "pre-commit")), "Should not install hooks after init failure"
    end
  end

  def test_everything_stops_when_hooks_fail
    Dir.mktmpdir("fun-ci-cli-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      # No .git/ → hook installation will fail
      stdout = StringIO.new
      exit_code = Dir.chdir(dir) { FunCi::Cli.run(["init", "--everything"], stdout: stdout, stderr: StringIO.new) }
      assert_equal 1, exit_code
      assert Dir.exist?(File.join(dir, ".fun-ci")), "Init should have succeeded"
      assert_match(/\.git/, stdout.string, "Should mention missing .git")
    end
  end
end
