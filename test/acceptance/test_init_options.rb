# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/cli_project"
require "fun_ci/setup/stage_templates"

# What init takes on its command line besides --everything.
class TestCliInitOptions < Minitest::Test
  include CliProject

  def test_writes_the_stack_named_after_stack
    add_gemfile
    run_cli("init", "--stack", "go")

    assert_equal FunCi::Setup::StageTemplates.scripts(:go)["lint.sh"], File.read(File.join(@dir, ".fun-ci", "lint.sh"))
  end

  def test_refuses_an_option_it_does_not_take
    assert_equal 64, run_cli("init", "--evrything")
  end

  def test_writes_nothing_for_an_option_it_does_not_take
    add_gemfile
    run_cli("init", "--evrything")

    refute fun_ci_dir_exists?
  end

  def test_names_the_option_it_does_not_take
    run_cli("init", "--evrything")

    assert_includes @stdout.string, "fun-ci init: invalid option: --evrything"
  end
end
