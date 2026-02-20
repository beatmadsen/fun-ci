# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/database"
require "tmpdir"

class TestDatabaseConnection < Minitest::Test
  def test_should_create_database_with_wal_mode
    # Given a temporary directory for the database
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "test.sqlite3")
      # When we open a database connection
      db = FunCi::Database.connection(db_path)
      # Then WAL mode should be enabled
      result = db.execute("PRAGMA journal_mode").first.first
      assert_equal "wal", result, "Database should use WAL journal mode"
      db.close
    end
  end

  def test_should_create_pipeline_runs_table
    # Given a fresh database
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "test.sqlite3")
      db = FunCi::Database.connection(db_path)
      FunCi::Database.migrate!(db)
      # When we query the schema
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
      # Then pipeline_runs table should exist
      assert_includes tables, "pipeline_runs", "Should create pipeline_runs table"
      db.close
    end
  end

  def test_should_create_stage_jobs_table
    # Given a fresh database
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "test.sqlite3")
      db = FunCi::Database.connection(db_path)
      FunCi::Database.migrate!(db)
      # When we query the schema
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
      # Then stage_jobs table should exist
      assert_includes tables, "stage_jobs", "Should create stage_jobs table"
      db.close
    end
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
    # Given a migrated database
    # When we inspect the pipeline_runs table schema
    columns = @db.execute("PRAGMA table_info(pipeline_runs)").map { |row| row[1] }
    # Then it should have the expected columns
    expected = %w[id commit_hash branch status created_at updated_at]
    expected.each do |col|
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
    # Given a migrated database
    # When we inspect the stage_jobs table schema
    columns = @db.execute("PRAGMA table_info(stage_jobs)").map { |row| row[1] }
    # Then it should have the expected columns
    expected = %w[id pipeline_run_id stage status started_at completed_at]
    expected.each do |col|
      assert_includes columns, col, "stage_jobs should have column '#{col}'"
    end
  end

  def test_should_enforce_foreign_key_on_stage_jobs
    # Given a migrated database with foreign keys enabled
    # When we try to insert a stage_job with a non-existent pipeline_run_id
    # Then it should raise an error
    error = assert_raises(SQLite3::ConstraintException) do
      @db.execute(
        "INSERT INTO stage_jobs (pipeline_run_id, stage, status) VALUES (?, ?, ?)",
        [99999, "build", "scheduled"]
      )
    end
    assert_match(/foreign key/i, error.message, "Should enforce foreign key constraint")
  end
end

class TestDatabaseMigrationIdempotency < Minitest::Test
  def test_should_be_safe_to_run_migration_twice
    # Given a database that has already been migrated
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "test.sqlite3")
      db = FunCi::Database.connection(db_path)
      FunCi::Database.migrate!(db)
      # When we run migration again
      # Then it should not raise
      FunCi::Database.migrate!(db)
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
      assert_includes tables, "pipeline_runs", "Tables should still exist after double migration"
      db.close
    end
  end
end
