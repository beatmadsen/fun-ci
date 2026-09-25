# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"

# AT-1.1: a pipeline runs in a worktree at the requested commit, never in the
# checkout someone is still editing.
class TestPipelineWorktree < Minitest::Test
  include EndToEnd

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

  def test_every_stage_runs_in_a_fun_ci_worktree
    trigger
    worktrees = %r{\A#{Regexp.escape(@project.common_dir)}/fun-ci/worktrees/slot-\d+ }

    assert_empty(GitProject::STAGES.reject { |stage| seen_by(stage).match?(worktrees) })
  end

  def test_every_stage_sees_the_requested_commit
    trigger

    assert_equal([@sha] * 4, GitProject::STAGES.map { |stage| seen_by(stage).split.last })
  end

  private

  def seen_by(stage) = File.read(File.join(@record, stage))

  def trigger = super(@project, @sha, db_dir: File.join(@record, "db"))
end
