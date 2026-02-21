# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/trigger"
require "fun_ci/database"
require "fun_ci/pipeline_recorder"
require "tmpdir"

# Acceptance test for the --no-validate fork safety contract.
#
# Verifies that the parent's DB connection is closed BEFORE the forker
# is called, preventing SQLite fork safety warnings when PipelineForker
# forks the process.
#
# Uses a spy forker that records whether the DB was closed at call time.
# Deterministic — no real fork, no timing, no STDERR capture.

class TestNoValidateForkSafety < Minitest::Test
  def test_should_close_db_before_calling_forker
    # Given: a real DB connection (as Cli#run_trigger creates)
    dir = Dir.mktmpdir("fun-ci-fork-safety")
    db_path = File.join(dir, "test.sqlite3")
    db = FunCi::Database.connection(db_path)
    FunCi::Database.migrate!(db)
    recorder = FunCi::DbRecorder.new(db)

    # A spy forker that records whether the parent DB was closed
    db_was_closed_before_fork = nil
    spy_forker = ->(commit_hash:, branch:, db_path:) {
      db_was_closed_before_fork = recorder.db.closed?
    }

    # When: run_from_args with --no-validate
    exit_code = FunCi::Trigger.run_from_args(
      ["--no-validate", "abc1234", "main"],
      stdout: StringIO.new,
      stderr: StringIO.new,
      recorder: recorder,
      pipeline_forker: spy_forker
    )

    # Then: exit code should be 0
    assert_equal 0, exit_code

    # And: the DB must have been closed before the forker was called
    assert db_was_closed_before_fork,
      "Parent DB should be closed before calling the forker to prevent SQLite fork safety warnings"
  ensure
    db&.close rescue nil
    FileUtils.remove_entry(dir) rescue nil
  end
end
