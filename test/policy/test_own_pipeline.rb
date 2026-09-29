# frozen_string_literal: true

require_relative "../test_helper"

# This repository runs its own pipeline with fun-ci (.fun-ci/): its stage
# scripts run every lane of the gate, the test lane as its four subsets, so a
# commit fun-ci passes is one the gate passes.
class TestOwnPipeline < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SUBSETS = %w[unit acceptance policy integration].freeze

  def test_should_run_every_lane_of_the_gate_but_the_test_lane_in_a_stage
    assert_empty gate_lanes - ["test"] - staged_tasks
  end

  def test_should_run_each_subset_of_the_test_lane_in_a_stage
    assert_empty SUBSETS - staged_tasks
  end

  def test_should_leave_no_test_of_the_test_lane_outside_the_subsets
    tests = Dir.glob("test/**/test_*.rb", base: ROOT) - ["test/test_helper.rb"]

    assert_empty(tests.reject { |path| SUBSETS.any? { |subset| path.start_with?("test/#{subset}/") } })
  end

  private

  def gate_lanes
    File.read(File.join(ROOT, "CLAUDE.md")).split(/^### /).find { |part| part.start_with?("Lanes\n") }
        .scan(/^bundle exec rake (\S+)/).flatten
  end

  # The rake tasks the stage scripts run, each word after `rake`.
  def staged_tasks
    Dir.glob(File.join(ROOT, ".fun-ci", "*.sh")).flat_map { |script| File.read(script).scan(/\brake (.*)$/) }
       .flatten.flat_map(&:split)
  end
end
