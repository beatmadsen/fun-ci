# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "stringio"

# What `fun-ci --help` says each command is for, in words someone who has
# never seen fun-ci can read.
class TestCliHelpWords < Minitest::Test
  def test_help_says_the_console_is_for_watching_the_runs
    assert_match(/^\s+console\s+Watch your runs as they happen, in the terminal$/, help)
  end

  def test_help_says_cancel_takes_the_job_option_too
    assert_match(/^\s+--job NAME\s+\(why, cancel\) /, help)
  end

  private

  def help
    stdout = StringIO.new
    FunCi::Cli.run(["--help"], io: FunCi::Pipeline::Io.new(stdout: stdout))
    stdout.string
  end
end
