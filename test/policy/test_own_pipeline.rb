# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/project_rakefile"

# This repository runs its own pipeline with fun-ci (.fun-ci/): its stage
# scripts run every lane of the gate, the test lane through subsets that
# together hold every one of its tests, so a commit fun-ci passes is one the
# gate passes.
class TestOwnPipeline < Minitest::Test
  ROOT = ProjectRakefile::ROOT

  def test_should_run_every_lane_of_the_gate_but_the_test_lane_in_a_stage
    assert_empty gate_lanes - ["test"] - staged_tasks
  end

  def test_should_run_every_test_of_the_test_lane_in_a_stage
    staged = (staged_tasks & TEST_LANES.keys).flat_map { |lane| ProjectRakefile.test_files(lane) }

    assert_empty ProjectRakefile.test_files("test") - ["test/test_helper.rb"] - staged
  end

  # The suites run side by side on what build.sh built (design.md, Stages side
  # by side), and only slow.sh runs cargo test, whose test targets the build
  # compiles so that no suite compiles anything.
  def test_should_compile_the_renderer_s_tests_in_the_build_stage
    assert_match(/cargo build .*--all-targets/, File.read(File.join(ROOT, ".fun-ci", "build.sh")))
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
