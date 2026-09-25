# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"

# AT-1.2: edits nobody has committed don't reach a pipeline.
class TestUncommittedChanges < Minitest::Test
  include EndToEnd

  def setup
    @project = GitProject.create
    @record = Dir.mktmpdir("stage-record")
    @project.write("value.txt", "committed\n")
    @project.write_stage_scripts { |stage| "cat value.txt > #{@record}/#{stage}" }
    @sha = @project.commit("value and stage scripts")
    @project.write("value.txt", "edited, not committed\n")
  end

  def teardown
    [@project.dir, @record].each { |dir| FileUtils.rm_rf(dir) }
  end

  def test_every_stage_sees_the_committed_content_not_the_edit
    trigger(@project, @sha, db_dir: File.join(@record, "db"))

    assert_equal(["committed\n"] * 4, GitProject::STAGES.map { |stage| File.read(File.join(@record, stage)) })
  end
end
