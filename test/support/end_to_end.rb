# frozen_string_literal: true

require "stringio"
require "fun_ci/cli"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require_relative "git_project"

# Runs `fun-ci trigger` in a GitProject the way a git hook would, and waits
# for the slow suite the run forks, so stage scripts' records are complete.
module EndToEnd
  def trigger(project, sha, db_dir:)
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    Dir.chdir(project.dir) { FunCi::Cli.run(["trigger", sha, "main"], io: io, db_dir: db_dir) }
    wait_for_slow_suite(File.join(db_dir, "db.sqlite3"), sha)
  end

  def wait_for_slow_suite(db_path, sha)
    db = FunCi::Persistence::Database.connection(db_path)
    pid = FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first[:pid]
    Thread.list.grep(Process::Waiter).find { |waiter| waiter.pid == pid }&.join
  ensure
    db&.close
  end
end
