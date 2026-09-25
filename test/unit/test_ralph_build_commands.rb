# frozen_string_literal: true

require "test_helper"
require "shellwords"
require "yaml"

# Ralphify splits each command with shlex and runs it without a shell, so a
# bare `&&`, `|` or `2>&1` reaches the program as an argument.
class TestRalphBuildCommands < Minitest::Test
  RALPH_MD = File.expand_path("../../ralph/build/RALPH.md", __dir__)
  SHELL_TOKEN = /\A(&&|\|\||\||;|\d?>.*|<.*)\z/

  def test_no_command_relies_on_shell_syntax_outside_bash_c
    offenders = commands.select { |c| Shellwords.split(c["run"]).any?(SHELL_TOKEN) }

    assert_empty offenders.map { |c| c["name"] }
  end

  private

  def commands
    YAML.safe_load(File.read(RALPH_MD).split(/^---$/)[1])["commands"]
  end
end
