# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/cli_project"

class TestCliInstallHooks < Minitest::Test
  include CliProject

  def setup
    super
    git_init
  end

  def test_installs_succeeds_in_a_git_repository
    assert_equal 0, run_cli("install-hooks")
  end

  %w[post-commit pre-push].each do |hook|
    define_method(:"test_installs_#{hook}_when_no_type_given") do
      run_cli("install-hooks")

      assert hook_exists?(hook)
    end
  end

  def test_installs_the_hook_type_given
    run_cli("install-hooks", "pre-push")

    assert hook_exists?("pre-push")
  end

  def test_installs_no_other_hook_when_a_type_is_given
    run_cli("install-hooks", "pre-push")

    refute hook_exists?("post-commit")
  end

  # AT-1.8: the background hook runs after the commit, not before it.
  def test_installs_no_pre_commit_hook
    run_cli("install-hooks")

    refute hook_exists?("pre-commit")
  end

  # AT-1.9: upgrading from 1.x takes out the pre-commit hook fun-ci wrote.
  def test_removes_fun_ci_s_1x_pre_commit_hook
    File.write(hook_path("pre-commit"), "#!/bin/sh\n# fun-ci-managed-hook\nfun-ci trigger --no-validate\n")
    run_cli("install-hooks")

    refute hook_exists?("pre-commit")
  end
end

class TestCliInitEverything < Minitest::Test
  include CliProject

  def setup
    super
    git_init
  end

  def test_everything_succeeds_for_a_ruby_project_in_a_git_repository
    add_gemfile

    assert_equal 0, run_cli("init", "--everything")
  end

  %w[post-commit pre-push].each do |hook|
    define_method(:"test_everything_installs_#{hook}") do
      add_gemfile
      run_cli("init", "--everything")

      assert hook_exists?(hook)
    end
  end

  def test_everything_succeeds_when_run_twice
    add_gemfile
    run_cli("init", "--everything")

    assert_equal 0, run_cli("init", "--everything")
  end

  def test_everything_fails_when_init_fails
    assert_equal 1, run_cli("init", "--everything")
  end

  def test_everything_installs_no_hooks_when_init_fails
    run_cli("init", "--everything")

    refute hook_exists?("post-commit")
  end
end
