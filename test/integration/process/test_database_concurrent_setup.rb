# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/persistence/database"
require "tmpdir"

# Two hooks can start fun-ci at once against a database that does not exist
# yet. Unserialised, some of them died on "database is locked" (switching to
# WAL) or "duplicate column name" (a column added between another process's
# check and its ALTER): 14 of 320 opens across 40 rounds of 8. At that rate
# 25 rounds all passing by luck has odds near 1 in 10,000.
class TestDatabaseConcurrentSetup < Minitest::Test
  ROUNDS = 25
  PROCESSES = 8

  def test_processes_setting_up_a_new_database_at_once_all_succeed
    assert_empty(ROUNDS.times.flat_map { Dir.mktmpdir { |dir| setup_errors(File.join(dir, "db.sqlite3")) } })
  end

  private

  def setup_errors(path)
    reader, writer = IO.pipe
    pids = PROCESSES.times.map { fork { set_up(path, reader, writer) } }
    writer.close
    pids.each { |pid| Process.wait(pid) }
    reader.read.lines
  end

  def set_up(path, reader, writer)
    reader.close
    open_and_migrate(path)
  rescue SQLite3::Exception => e
    writer.puts("#{e.class}: #{e.message}")
  ensure
    exit!(0)
  end

  def open_and_migrate(path)
    db = FunCi::Persistence::Database.connection(path)
    FunCi::Persistence::Database.migrate!(db)
    db.close
  end
end
