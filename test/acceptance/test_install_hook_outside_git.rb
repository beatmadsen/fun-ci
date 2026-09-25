# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/cli_project"
require "fun_ci/setup/hook_writer"
require "fun_ci/setup/installer"

class TestInstallHookOutsideGit < Minitest::Test
  include CliProject

  def test_should_refuse_when_not_in_a_git_repo
    assert_equal 1, install_pre_commit_hook
  end

  def test_should_say_the_git_directory_is_missing
    install_pre_commit_hook

    assert_match(/\.git/i, @stdout.string)
  end

  def test_init_should_succeed_when_fun_ci_already_exists
    Dir.mkdir(File.join(@dir, ".fun-ci"))

    assert_equal 0, FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)
  end

  def test_init_should_explain_it_skipped_an_existing_fun_ci_directory
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)

    assert_match(/already exists/i, @stdout.string)
  end

  private

  def install_pre_commit_hook
    FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: "pre-commit", stdout: @stdout)
  end
end
