# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/mutation_lanes"

# Which mutation lanes the nightly workflow runs, from the files changed since
# its last finished run: a lane runs only when something it depends on did.
class TestMutationLanes < Minitest::Test
  def test_should_run_the_ruby_lane_when_lib_changed
    assert_equal({ "ruby" => true, "rust" => false }, MutationLanes.for(["lib/fun_ci/cli.rb"]))
  end

  def test_should_run_the_ruby_lane_when_a_test_changed
    assert_equal({ "ruby" => true, "rust" => false }, MutationLanes.for(["test/unit/test_cli.rb"]))
  end

  def test_should_run_the_rust_lane_when_the_renderer_changed
    assert_equal({ "ruby" => false, "rust" => true }, MutationLanes.for(["renderer/src/screen.rs"]))
  end

  def test_should_run_the_rust_lane_when_a_scenario_its_tests_read_changed
    assert_equal({ "ruby" => false, "rust" => true }, MutationLanes.for(["contract/scenarios/running.jsonl"]))
  end

  def test_should_run_both_lanes_when_what_runs_them_changed
    assert_equal({ "ruby" => true, "rust" => true }, MutationLanes.for([".github/workflows/mutation.yml"]))
  end

  def test_should_run_neither_lane_when_only_the_docs_changed
    assert_equal({ "ruby" => false, "rust" => false }, MutationLanes.for(["README.md", "docs/design.md"]))
  end

  def test_should_run_every_lane_with_no_finished_run_to_compare_with
    assert_equal({ "ruby" => true, "rust" => true }, MutationLanes.for(nil))
  end

  def test_should_say_the_lanes_as_github_step_outputs
    assert_equal "ruby=true\nrust=false\n", MutationLanes.outputs({ "ruby" => true, "rust" => false })
  end
end
