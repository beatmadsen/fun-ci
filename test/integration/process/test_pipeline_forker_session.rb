# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/pipeline_forker"
require "fun_ci/persistence/database"

# The run the post-commit hook starts leaves the session of the shell that
# committed, so that Ctrl-C in that terminal, an agent harness ending the
# command, or the terminal closing doesn't end it with the commit's CI half run.
class TestPipelineForkerSession < Minitest::Test
  include ProcessDeadline

  def setup
    @dir = Dir.mktmpdir("pipeline-forker-session")
    @db_path = File.join(@dir, "db.sqlite3")
    FunCi::Persistence::Database.connection(@db_path).tap { |db| FunCi::Persistence::Database.migrate!(db) }.close
    @project = GitProject.create
    @project.write_stage_scripts { |stage| stage == "slow" ? "ruby -e 'print Process.getsid' > '#{seen}'" : "exit 0" }
    @sha = @project.commit("Add stages")
  end

  def teardown
    FileUtils.rm_rf(@dir)
    @project.remove
  end

  def test_should_run_the_slow_suite_outside_the_session_that_committed
    forked_to_the_end

    refute_equal Process.getsid.to_s, File.read(seen)
  end

  private

  def seen = File.join(@dir, "session")

  # Every process the run forks inherits a pipe this holds, whose end comes
  # when the last of them, the slow suite's included, has exited.
  def forked_to_the_end
    ended, held = IO.pipe
    Dir.chdir(@project.dir) do
      FunCi::Pipeline::PipelineForker.fork_pipeline(commit_hash: @sha, branch: "main", db_path: @db_path,
                                                    jobs: ->(*) {})
    end
    held.close
    within_deadline { ended.read }
  end
end
