# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "tmpdir"
require "stringio"

module CliSubcommandProject
  def setup
    @dir = Dir.mktmpdir("fun-ci-cli-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def add_gemfile
    File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\n")
  end

  def git_init
    system("git", "init", "--quiet", @dir)
  end

  def run_cli(*args)
    Dir.chdir(@dir) { FunCi::Cli.run(args, stdout: @stdout, stderr: StringIO.new) }
  end

  def hook_exists?(name)
    File.exist?(File.join(@dir, ".git", "hooks", name))
  end

  def fun_ci_dir_exists?
    Dir.exist?(File.join(@dir, ".fun-ci"))
  end
end

class TestCliInitSubcommand < Minitest::Test
  include CliSubcommandProject

  def test_init_creates_fun_ci_directory_through_cli
    add_gemfile
    assert_equal 0, run_cli("init")
    assert fun_ci_dir_exists?, ".fun-ci/ should be created"
  end

  def test_init_skips_when_fun_ci_already_exists
    add_gemfile
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    assert_equal 0, run_cli("init"), "Should return 0 when skipping (idempotent)"
  end
end

class TestCliInstallHooksBothByDefault < Minitest::Test
  include CliSubcommandProject

  def test_installs_both_hooks_when_no_type_given
    git_init
    assert_equal 0, run_cli("install-hooks")
    assert hook_exists?("pre-commit"), "pre-commit should exist"
    assert hook_exists?("pre-push"), "pre-push should exist"
  end

  def test_installs_only_specified_hook_when_type_given
    git_init
    assert_equal 0, run_cli("install-hooks", "pre-push")
    assert hook_exists?("pre-push"), "pre-push should exist"
    refute hook_exists?("pre-commit"), "pre-commit should NOT exist"
  end
end

class TestCliCheckSubcommand < Minitest::Test
  include CliSubcommandProject
  include FunCiTestProject

  def test_check_succeeds_for_configured_project
    make_project_with_scripts(@dir)
    assert_equal 0, run_cli("check")
  end

  def test_check_fails_when_scripts_missing
    assert_equal 1, run_cli("check")
  end
end

class TestCliInitEverything < Minitest::Test
  include CliSubcommandProject

  def test_everything_runs_init_hooks_and_check
    add_gemfile
    git_init
    assert_equal 0, run_cli("init", "--everything")
    assert fun_ci_dir_exists?, ".fun-ci/ should be created"
    assert hook_exists?("pre-commit"), "pre-commit hook"
    assert hook_exists?("pre-push"), "pre-push hook"
  end

  def test_everything_stops_when_init_fails
    git_init
    assert_equal 1, run_cli("init", "--everything")
    refute hook_exists?("pre-commit"), "Should not install hooks after init failure"
  end

  # Without .git/ hook installation fails.
  def test_everything_stops_when_hooks_fail
    add_gemfile
    assert_equal 1, run_cli("init", "--everything")
    assert fun_ci_dir_exists?, "Init should have succeeded"
    assert_match(/\.git/, @stdout.string, "Should mention missing .git")
  end
end
