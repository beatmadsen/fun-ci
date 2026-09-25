# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/end_to_end"

# AT-1.3: the next run in a slot keeps what .gitignore ignores (caches such as
# vendor/bundle, so builds stay fast) and loses what a run left untracked.
# The slow suite leaves both behind; the next run's lint, which runs before
# that run's slow suite, looks for them.
class TestSlotReuse < Minitest::Test
  include EndToEnd

  LOOK = %w[vendor/cache/marker scratch.txt].map do |file|
    "test -f #{file} && echo kept >> $RECORD/#{File.basename(file)} || echo gone >> $RECORD/#{File.basename(file)}"
  end.join("\n")

  def setup
    @project = GitProject.create
    @record = Dir.mktmpdir("stage-record")
    @project.write(".gitignore", "vendor/cache/\n")
    @project.write_stage_scripts { |stage| script_for(stage) }
    [commit("first"), commit("second")].each { |sha| trigger(@project, sha, db_dir: File.join(@record, "db")) }
  end

  def teardown
    [@project.dir, @record].each { |dir| FileUtils.rm_rf(dir) }
  end

  def test_the_next_run_in_the_slot_still_has_the_ignored_cache
    assert_equal %w[gone kept], File.readlines(File.join(@record, "marker"), chomp: true)
  end

  def test_the_next_run_in_the_slot_has_lost_the_untracked_file
    assert_equal %w[gone gone], File.readlines(File.join(@record, "scratch.txt"), chomp: true)
  end

  private

  def commit(name)
    @project.write("#{name}.txt", name)
    @project.commit(name)
  end

  def script_for(stage)
    { "lint" => "RECORD=#{@record}\n#{LOOK}",
      "slow" => "mkdir -p vendor/cache && touch vendor/cache/marker scratch.txt" }.fetch(stage, "true")
  end
end
