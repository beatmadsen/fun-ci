# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/evidence/start"

# What a stage's evidence starts from, read from its worktree when it starts
# (why.md, "Choosing which run").
class TestEvidenceStart < Minitest::Test
  def setup
    @worktree = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@worktree, ".fun-ci"))
    File.write(File.join(@worktree, "Gemfile"), "")
  end

  def teardown = FileUtils.remove_entry(@worktree)

  def test_should_take_the_presets_whose_markers_the_worktree_has_as_candidates
    assert_equal %w[rspec minitest logstash ecs], candidates
  end

  def test_should_take_no_candidates_when_detection_is_off
    assert_empty candidates("evidence:\n  detect: false\n")
  end

  def test_should_leave_out_a_preset_it_is_told_to_skip
    assert_equal %w[minitest logstash ecs], candidates("evidence:\n  skip: [rspec]\n")
  end

  def test_should_leave_out_a_preset_the_stage_s_entries_name
    assert_equal %w[minitest logstash ecs],
                 candidates("evidence:\n  stages:\n    fast:\n      - use: section\n        preset: rspec\n")
  end

  private

  def candidates(config = nil)
    File.write(File.join(@worktree, ".fun-ci", "config"), config) if config
    settings = FunCi::Evidence::Settings.load(File.join(@worktree, ".fun-ci", "config"))
    FunCi::Evidence::Start.candidates(FunCi::Evidence::Worktree.new(@worktree), settings, "fast")
                          .map { |found| found.preset.name }
  end
end
