# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "fun_ci/cli_command_help"
require "stringio"

# `fun-ci COMMAND --help`: the command's usage, printed instead of running it.
class TestCliCommandHelp < Minitest::Test
  def test_should_not_run_a_command_asked_for_its_help
    ran = []
    FunCi::Cli.run(%w[init --help], io: io, handlers: { "init" => ->(args) { ran << args } })

    assert_empty ran
  end

  def test_should_exit_zero_when_a_command_is_asked_for_its_help
    assert_equal 0, FunCi::Cli.run(%w[prune --help], io: io)
  end

  def test_should_print_the_command_s_usage
    assert_match(/^Usage: fun-ci init \[--everything\]$/, help_of("init", "--help"))
  end

  def test_should_take_the_short_flag_too
    assert_match(/^Usage: fun-ci check$/, help_of("check", "-h"))
  end

  def test_should_find_the_flag_after_other_arguments
    assert_match(/^Usage: fun-ci why /, help_of("why", "abc123", "--help"))
  end

  def test_should_say_what_the_command_is_for
    assert_match(/^Watch your runs as they happen, in the terminal$/, help_of("console", "--help"))
  end

  def test_should_list_the_options_the_command_takes
    assert_match(/^\s+--within TIME\s/, help_of("wait", "--help"))
  end

  def test_should_leave_out_the_options_other_commands_take
    refute_match(/--raw/, help_of("wait", "--help"))
  end

  def test_should_list_the_options_of_a_command_with_a_section_of_its_own
    assert_match(/^\s+--background\s/, help_of("trigger", "--help"))
  end

  def test_should_give_every_command_a_usage
    assert_equal (FunCi::Cli::ROUTES.keys + FunCi::Cli::AGENT_COMMANDS).sort,
                 FunCi::CliCommandHelp::USAGES.keys.sort
  end

  private

  def io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)

  def help_of(*args)
    stdout = StringIO.new
    FunCi::Cli.run(args, io: FunCi::Pipeline::Io.new(stdout: stdout))
    stdout.string
  end
end
