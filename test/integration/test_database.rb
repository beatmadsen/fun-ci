# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "tmpdir"

module FreshDatabaseFile
  def setup
    @dir = Dir.mktmpdir
    @db = FunCi::Persistence::Database.connection(File.join(@dir, "test.sqlite3"))
  end

  def teardown
    @db.close
    FileUtils.remove_entry @dir
  end

  def table_names
    @db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
  end
end

class TestDatabaseConnection < Minitest::Test
  include FreshDatabaseFile

  def test_should_create_database_with_wal_mode
    result = @db.execute("PRAGMA journal_mode").first.first
    assert_equal "wal", result, "Database should use WAL journal mode"
  end

  def test_should_create_pipeline_runs_table
    FunCi::Persistence::Database.migrate!(@db)
    assert_includes table_names, "pipeline_runs", "Should create pipeline_runs table"
  end

  def test_should_create_stage_jobs_table
    FunCi::Persistence::Database.migrate!(@db)
    assert_includes table_names, "stage_jobs", "Should create stage_jobs table"
  end
end

class TestDatabasePipelineRunsSchema < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_have_expected_columns_on_pipeline_runs
    columns = @db.execute("PRAGMA table_info(pipeline_runs)").map { |row| row[1] }
    %w[id commit_hash branch status pid created_at updated_at].each do |col|
      assert_includes columns, col, "pipeline_runs should have column '#{col}'"
    end
  end
end

class TestDatabaseStageJobsSchema < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_have_expected_columns_on_stage_jobs
    columns = @db.execute("PRAGMA table_info(stage_jobs)").map { |row| row[1] }
    %w[id pipeline_run_id stage status started_at completed_at].each do |col|
      assert_includes columns, col, "stage_jobs should have column '#{col}'"
    end
  end

  def test_should_enforce_foreign_key_on_stage_jobs
    error = assert_raises(SQLite3::ConstraintException) do
      @db.execute(
        "INSERT INTO stage_jobs (pipeline_run_id, stage, status) VALUES (?, ?, ?)",
        [99_999, "build", "scheduled"]
      )
    end
    assert_match(/foreign key/i, error.message, "Should enforce foreign key constraint")
  end
end

class TestDatabaseMigrationFromOlderSchema < Minitest::Test
  include FreshDatabaseFile

  def test_should_add_the_pid_column_to_a_table_created_before_it_existed
    @db.execute("CREATE TABLE pipeline_runs (id INTEGER PRIMARY KEY, commit_hash TEXT, branch TEXT, status TEXT)")
    FunCi::Persistence::Database.migrate!(@db)

    assert_includes @db.execute("PRAGMA table_info(pipeline_runs)").map { |row| row[1] }, "pid"
  end
end

# Stands in for a connection and notes, at each statement, whether the setup
# lock is held: a non-blocking flock through another descriptor fails then.
class LockCheckingDb
  attr_reader :held

  def initialize(path)
    @path = path
    @held = []
  end

  def filename(_database) = @path
  def busy_timeout=(_millis); end

  def execute(_sql)
    @held << File.open("#{@path}.setup-lock", File::RDWR | File::CREAT) { |f| !f.flock(File::LOCK_EX | File::LOCK_NB) }
    []
  end
end

class TestDatabaseSetupLock < Minitest::Test
  def test_migrating_holds_the_setup_lock_for_every_statement
    held = statements_under_lock { |db| FunCi::Persistence::Database.migrate!(db) }

    assert_equal [true], held
  end

  def test_opening_holds_the_setup_lock_while_switching_to_wal
    held = statements_under_lock { |db| FunCi::Persistence::Database.connection(db.filename(:main), open: ->(_) { db }) }

    assert_equal [true], held
  end

  private

  def statements_under_lock
    Dir.mktmpdir do |dir|
      db = LockCheckingDb.new(File.join(dir, "db.sqlite3"))
      yield db
      db.held.uniq
    end
  end
end

class TestDatabaseMigrationIdempotency < Minitest::Test
  include FreshDatabaseFile

  def test_should_be_safe_to_run_migration_twice
    FunCi::Persistence::Database.migrate!(@db)
    FunCi::Persistence::Database.migrate!(@db)
    assert_includes table_names, "pipeline_runs", "Tables should still exist after double migration"
  end
end
