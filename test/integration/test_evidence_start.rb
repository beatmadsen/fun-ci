# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/evidence/start"

# What a stage's evidence starts from, read from its worktree when it starts
# (architecture.md, "Evidence of a failed stage").
class TestEvidenceStart < Minitest::Test
  def setup
    @worktree = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@worktree, ".fun-ci"))
    File.write(File.join(@worktree, "Gemfile"), "")
  end

  def teardown = FileUtils.remove_entry(@worktree)

  def test_should_take_a_preset_whose_marker_the_worktree_has_as_a_candidate
    assert_includes candidates, "rspec"
  end

  def test_should_not_take_a_preset_whose_markers_the_worktree_lacks
    refute_includes candidates, "gradle"
  end

  def test_should_take_no_candidates_when_detection_is_off
    assert_empty candidates("evidence:\n  detect: false\n")
  end

  def test_should_leave_out_a_preset_it_is_told_to_skip
    refute_includes candidates("evidence:\n  skip: [rspec]\n"), "rspec"
  end

  def test_should_leave_out_a_preset_the_stage_s_entries_name
    refute_includes candidates("evidence:\n  stages:\n    fast:\n      - use: section\n        preset: rspec\n"),
                    "rspec"
  end

  private

  def candidates(config = nil)
    File.write(File.join(@worktree, ".fun-ci", "config"), config) if config
    settings = FunCi::Evidence::Settings.load(File.join(@worktree, ".fun-ci", "config"))
    FunCi::Evidence::Start.candidates(FunCi::Evidence::Worktree.new(@worktree), settings, "fast")
                          .map { |found| found.preset.name }
  end
end
