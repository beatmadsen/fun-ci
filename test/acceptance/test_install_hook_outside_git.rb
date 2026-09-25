# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/cli_project"
require "fun_ci/setup/hook_writer"
require "fun_ci/setup/installer"

class TestInstallHookOutsideGit < Minitest::Test
  include CliProject

  def test_init_should_succeed_when_fun_ci_already_exists
    Dir.mkdir(File.join(@dir, ".fun-ci"))

    assert_equal 0, FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)
  end

  def test_init_should_explain_it_skipped_an_existing_fun_ci_directory
    Dir.mkdir(File.join(@dir, ".fun-ci"))
    FunCi::Setup::Installer.run(project_root: @dir, stdout: @stdout)

    assert_match(/already exists/i, @stdout.string)
  end
end
