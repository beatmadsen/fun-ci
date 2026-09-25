# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/git_project"
require "fun_ci/cli"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# AT-1.1: a pipeline runs in a worktree at the requested commit, never in the
# checkout someone is still editing.
class TestPipelineWorktree < Minitest::Test
  def setup
    @project = GitProject.create
    @record = Dir.mktmpdir("stage-record")
    @project.write_stage_scripts { |stage| %(echo "$(pwd -P) $(git rev-parse HEAD)" > #{@record}/#{stage}) }
    @sha = @project.commit("stage scripts")
    @project.write("later.txt", "a later commit moves HEAD past the one under test")
    @project.commit("later")
  end

  def teardown
    [@project.dir, @record].each { |dir| FileUtils.rm_rf(dir) }
  end

  GitProject::STAGES.each do |stage|
    define_method(:"test_#{stage}_runs_in_a_fun_ci_worktree") do
      trigger

      assert_match(%r{\A#{Regexp.escape(@project.common_dir)}/fun-ci/worktrees/slot-\d+ }, seen_by(stage))
    end

    define_method(:"test_#{stage}_sees_the_requested_commit") do
      trigger

      assert_equal @sha, seen_by(stage).split.last
    end
  end

  private

  def seen_by(stage) = File.read(File.join(@record, stage))

  def trigger
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    db_dir = File.join(@record, "db")
    Dir.chdir(@project.dir) { FunCi::Cli.run(["trigger", @sha, "main"], io: io, db_dir: db_dir) }
    wait_for_slow_suite(File.join(db_dir, "db.sqlite3"))
  end

  def wait_for_slow_suite(db_path)
    db = FunCi::Persistence::Database.connection(db_path)
    pid = FunCi::Persistence::PipelineRun.find_by_commit(db, @sha).first[:pid]
    Thread.list.grep(Process::Waiter).find { |waiter| waiter.pid == pid }&.join
  ensure
    db&.close
  end
end
