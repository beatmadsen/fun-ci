# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "stringio"

class TestCliUnknownSubcommand < Minitest::Test
  def test_returns_one_for_unknown_subcommand
    stderr = StringIO.new
    exit_code = FunCi::Cli.run(["bogus"], stderr: stderr)
    assert_equal 1, exit_code
  end

  def test_prints_error_for_unknown_subcommand
    stderr = StringIO.new
    FunCi::Cli.run(["bogus"], stderr: stderr)
    assert_match(/unknown command 'bogus'/, stderr.string)
    assert_match(/fun-ci --help/, stderr.string)
  end
end

class TestCliNoSubcommand < Minitest::Test
  def test_returns_one_with_no_args
    stderr = StringIO.new
    exit_code = FunCi::Cli.run([], stderr: stderr)
    assert_equal 1, exit_code
  end

  def test_prints_help_hint_with_no_args
    stderr = StringIO.new
    FunCi::Cli.run([], stderr: stderr)
    assert_match(/fun-ci --help/, stderr.string)
  end
end

class TestCliRouting < Minitest::Test
  def test_routes_trigger_subcommand
    routed = nil
    handlers = { "trigger" => ->(args) { routed = [:trigger, args]; 0 } }
    exit_code = FunCi::Cli.run(["trigger", "abc123", "main"], handlers: handlers)
    assert_equal [:trigger, ["abc123", "main"]], routed
    assert_equal 0, exit_code
  end

  def test_routes_console_subcommand
    routed = nil
    handlers = { "console" => ->(args) { routed = [:console, args]; 0 } }
    exit_code = FunCi::Cli.run(["console"], handlers: handlers)
    assert_equal [:console, []], routed
    assert_equal 0, exit_code
  end

  def test_routes_init_subcommand
    routed = nil
    handlers = { "init" => ->(args) { routed = [:init, args]; 0 } }
    exit_code = FunCi::Cli.run(["init"], handlers: handlers)
    assert_equal [:init, []], routed
    assert_equal 0, exit_code
  end

  def test_routes_install_hooks_subcommand
    routed = nil
    handlers = { "install-hooks" => ->(args) { routed = [:install_hooks, args]; 0 } }
    exit_code = FunCi::Cli.run(["install-hooks", "pre-push"], handlers: handlers)
    assert_equal [:install_hooks, ["pre-push"]], routed
    assert_equal 0, exit_code
  end

  def test_routes_check_subcommand
    routed = nil
    handlers = { "check" => ->(args) { routed = [:check, args]; 0 } }
    exit_code = FunCi::Cli.run(["check"], handlers: handlers)
    assert_equal [:check, []], routed
    assert_equal 0, exit_code
  end

  def test_returns_handler_exit_code
    handlers = { "check" => ->(_args) { 1 } }
    exit_code = FunCi::Cli.run(["check"], handlers: handlers)
    assert_equal 1, exit_code
  end
end

class TestCliHelp < Minitest::Test
  def test_help_flag_returns_zero
    stdout = StringIO.new
    exit_code = FunCi::Cli.run(["--help"], stdout: stdout)
    assert_equal 0, exit_code
  end

  def test_short_help_flag_returns_zero
    stdout = StringIO.new
    exit_code = FunCi::Cli.run(["-h"], stdout: stdout)
    assert_equal 0, exit_code
  end

  def test_help_lists_all_commands
    stdout = StringIO.new
    FunCi::Cli.run(["--help"], stdout: stdout)
    %w[trigger console init install-hooks check].each do |cmd|
      assert_match(/#{cmd}/, stdout.string, "Help should list '#{cmd}'")
    end
  end

  def test_help_includes_options
    stdout = StringIO.new
    FunCi::Cli.run(["--help"], stdout: stdout)
    assert_match(/--no-validate/, stdout.string)
    assert_match(/--everything/, stdout.string)
  end

  def test_help_prints_to_stdout_not_stderr
    stdout = StringIO.new
    stderr = StringIO.new
    FunCi::Cli.run(["--help"], stdout: stdout, stderr: stderr)
    refute_empty stdout.string
    assert_empty stderr.string
  end

  def test_version_flag_returns_zero
    stdout = StringIO.new
    exit_code = FunCi::Cli.run(["--version"], stdout: stdout)
    assert_equal 0, exit_code
    assert_match(/fun-ci \d+\.\d+\.\d+/, stdout.string)
  end
end
