# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/cli_project"
require "fun_ci/setup/hook_writer"

class TestInstallHookCli < Minitest::Test
  include CliProject

  FOREIGN_HOOK = "#!/bin/sh\n# husky managed hook\nnpx lint-staged\n"

  def test_should_report_success_when_installing_into_a_git_repository
    git_init

    assert_equal 0, install_pre_commit_hook
  end

  def test_should_name_the_hook_it_installed
    git_init
    install_pre_commit_hook

    assert_match(/pre-commit/, @stdout.string)
  end

  def test_should_write_an_executable_hook_file
    git_init
    install_pre_commit_hook

    assert File.executable?(hook_path("pre-commit"))
  end

  def test_should_write_a_hook_that_calls_fun_ci_trigger
    git_init
    install_pre_commit_hook

    assert_match(/fun-ci.*trigger/, File.read(hook_path("pre-commit")))
  end

  def test_should_mark_the_hook_as_managed_by_fun_ci
    git_init
    install_pre_commit_hook

    assert_match(/# fun-ci-managed-hook/, File.read(hook_path("pre-commit")))
  end

  def test_should_leave_a_foreign_hook_alone
    git_init
    File.write(hook_path("pre-commit"), FOREIGN_HOOK)
    install_pre_commit_hook

    assert_equal FOREIGN_HOOK, File.read(hook_path("pre-commit"))
  end

  def test_should_report_success_when_skipping_a_foreign_hook
    git_init
    File.write(hook_path("pre-commit"), FOREIGN_HOOK)

    assert_equal 0, install_pre_commit_hook
  end

  def test_should_say_a_foreign_hook_already_exists
    git_init
    File.write(hook_path("pre-commit"), FOREIGN_HOOK)
    install_pre_commit_hook

    assert_match(/already exists/i, @stdout.string)
  end

  private

  def install_pre_commit_hook
    FunCi::Setup::HookWriter.run(project_root: @dir, hook_type: "pre-commit", stdout: @stdout)
  end
end
