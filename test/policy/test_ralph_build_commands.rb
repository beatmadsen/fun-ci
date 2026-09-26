# frozen_string_literal: true

require "test_helper"
require "shellwords"
require "yaml"

# Ralphify splits each command with shlex and runs it without a shell, so a
# bare `&&`, `|` or `2>&1` reaches the program as an argument.
class TestRalphBuildCommands < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  RALPH_MD = File.join(ROOT, "ralph/build/RALPH.md")
  SHELL_TOKEN = /\A(&&|\|\||\||;|\d?>.*|<.*)\z/

  def test_no_command_relies_on_shell_syntax_outside_bash_c
    offenders = commands.select { |c| Shellwords.split(c["run"]).any?(SHELL_TOKEN) }

    assert_empty(offenders.map { |c| c["name"] })
  end

  # A command that reads a moved or deleted file puts an error in the prompt
  # where the document should be, and the loop carries on without it.
  def test_every_file_a_command_reads_exists
    missing = commands.flat_map { |c| files_read(c["run"]) }.reject { |path| File.exist?(File.join(ROOT, path)) }

    assert_empty(missing)
  end

  private

  def files_read(run) = Shellwords.split(run).each_cons(2).filter_map { |word, path| path if word == "cat" }

  def commands
    YAML.safe_load(File.read(RALPH_MD).split(/^---$/)[1])["commands"]
  end
end
