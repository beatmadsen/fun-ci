# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "tmpdir"

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
