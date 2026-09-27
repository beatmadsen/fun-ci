# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/git_project"
require_relative "../../../support/descendants"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"

# AT-9.11: the pipeline `wait` starts for a commit without a run is the one
# the post-commit hook would start, recorded in the same database. Descendants
# waits until the starter and the pipeline it forked have both finished.
class TestLivePipeline < Minitest::Test
  LIB = File.expand_path("../../../../lib", __dir__)
  START = "require 'fun_ci/agent/live_pipeline'; FunCi::Agent::LivePipeline.new(ARGV[0]).start(ARGV[1], 'main')"

  def setup
    @project = GitProject.create
    @project.write_stage_scripts { |_stage| "true" }
    @sha = @project.commit("Add stage scripts")
    @state = Dir.mktmpdir("live-pipeline")
    Descendants.spawn({ "XDG_STATE_HOME" => @state }, RbConfig.ruby, "-I", LIB, "-e", START, @project.dir, @sha,
                      %i[out err] => File::NULL).wait_for_all
  end

  def teardown = [@project.dir, @state].each { |dir| FileUtils.rm_rf(dir) }

  def test_should_run_the_commit_s_pipeline_to_its_end
    assert_equal "completed", run_of(@sha)[:status]
  end

  def test_should_record_the_run_on_the_branch_it_was_given
    assert_equal "main", run_of(@sha)[:branch]
  end

  private

  def run_of(sha)
    db = FunCi::Persistence::Database.connection(File.join(@state, "fun-ci", "db.sqlite3"))
    FunCi::Persistence::PipelineRun.find_by_commit(db, sha).first
  ensure
    db&.close
  end
end
