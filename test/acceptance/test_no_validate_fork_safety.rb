# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/trigger"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "tmpdir"

# The --no-validate path must close the parent's DB connection BEFORE calling
# the forker, or SQLite warns about fork safety when PipelineForker forks.
# A spy forker records whether the DB was closed at call time: no real fork.
class TestNoValidateForkSafety < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-fork-safety")
    db = FunCi::Persistence::Database.connection(File.join(@dir, "test.sqlite3"))
    FunCi::Persistence::Database.migrate!(db)
    @recorder = FunCi::Persistence::DbRecorder.new(db)
  end

  def teardown
    @recorder.db.close unless @recorder.db.closed?
    FileUtils.remove_entry(@dir)
  end

  def test_should_close_db_before_calling_forker
    db_was_closed_before_fork = nil
    exit_code = trigger_no_validate(->(**) { db_was_closed_before_fork = @recorder.db.closed? })
    assert_equal 0, exit_code
    assert db_was_closed_before_fork,
           "Parent DB should be closed before calling the forker to prevent SQLite fork safety warnings"
  end

  private

  def trigger_no_validate(forker)
    FunCi::Pipeline::Trigger.run_from_args(
      ["--no-validate", "abc1234", "main"],
      stdout: StringIO.new, stderr: StringIO.new, recorder: @recorder, pipeline_forker: forker
    )
  end
end
