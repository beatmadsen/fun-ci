# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "fun_ci/persistence/database"

# The temp directories and database one TriggerCliClient works in.
class TriggerWorkspace
  attr_reader :db, :project_dir

  def self.create
    db_dir = Dir.mktmpdir("fun-ci-test-db")
    db = FunCi::Persistence::Database.connection(File.join(db_dir, "test.sqlite3"))
    FunCi::Persistence::Database.migrate!(db)
    new(db_dir, db, Dir.mktmpdir("fun-ci-test"))
  end

  def initialize(db_dir, db, project_dir)
    @db_dir = db_dir
    @db = db
    @project_dir = project_dir
  end

  def close
    @db.close
    FileUtils.rm_rf([@db_dir, @project_dir])
  end
end
