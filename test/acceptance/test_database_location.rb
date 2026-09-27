# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/cli"
require "stringio"

# Every fun-ci command opens the same database, in the user's state directory,
# whatever TMPDIR the process has (acceptance-tests.md, AT-9.1).
class TestDatabaseLocation < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-state-test")
    @saved = ENV.to_h.slice("XDG_STATE_HOME", "HOME")
  end

  def teardown
    %w[XDG_STATE_HOME HOME].each { |name| ENV[name] = @saved[name] }
    FileUtils.remove_entry(@dir)
  end

  def test_should_keep_the_database_in_the_xdg_state_home_when_one_is_set
    ENV["XDG_STATE_HOME"] = File.join(@dir, "state")
    trigger_without_a_project

    assert_path_exists File.join(@dir, "state", "fun-ci", "db.sqlite3")
  end

  def test_should_keep_the_database_under_the_home_directory_without_an_xdg_state_home
    ENV.delete("XDG_STATE_HOME")
    ENV["HOME"] = @dir
    trigger_without_a_project

    assert_path_exists File.join(@dir, ".local", "state", "fun-ci", "db.sqlite3")
  end

  private

  def trigger_without_a_project
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    Dir.chdir(@dir) { FunCi::Cli.run(%w[trigger abc1234 main], io: io) }
  end
end
