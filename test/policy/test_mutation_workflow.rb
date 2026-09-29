# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# The mutation lanes take hours, so they run nightly rather than on each push,
# and only a lane something it depends on changed for since the last finished
# run (script/mutation_lanes.rb decides which).
class TestMutationWorkflow < Minitest::Test
  WORKFLOW = File.expand_path("../../.github/workflows/mutation.yml", __dir__)
  LANES = { "mutation" => "ruby", "mutation-rust" => "rust", "mutation-rust-score" => "rust" }.freeze

  def test_should_run_nightly
    assert_equal 1, triggers.fetch("schedule").size
  end

  def test_should_run_when_started_by_hand
    assert triggers.key?("workflow_dispatch")
  end

  def test_should_not_run_on_a_push
    refute triggers.key?("push")
  end

  def test_should_decide_the_lanes_from_what_changed_since_the_last_finished_run
    assert(commands("changes").any? { |command| command.include?("ruby script/mutation_lanes.rb") })
  end

  def test_should_compare_with_the_last_run_that_finished
    assert(commands("changes").any? { |command| command.include?("gh run list --workflow mutation.yml") })
  end

  def test_should_run_each_lane_only_when_it_changed
    assert_equal(LANES.to_h { |job, lane| [job, "needs.changes.outputs.#{lane} == 'true'"] },
                 LANES.keys.to_h { |job| [job, jobs.dig(job, "if")] })
  end

  def test_should_run_the_ruby_lane_on_the_oldest_ruby_that_installs_mutineer
    assert_equal "3.4", setup_ruby("mutation").dig("with", "ruby-version")
  end

  def test_should_run_the_ruby_mutation_lane
    assert_includes commands("mutation"), "bundle exec rake mutation"
  end

  def test_should_run_every_shard_of_the_rust_mutants
    shards = jobs.dig("mutation-rust", "strategy", "matrix", "shard")
    command = "bundle exec rake \"mutation:rust:shard[${{ matrix.shard }},#{shards.size}]\""

    run = commands("mutation-rust").grep(/mutation:rust:shard/).first

    assert_equal [(0...shards.size).to_a, command], [shards, run]
  end

  def test_should_judge_the_rust_mutants_on_every_shard_together
    shards = jobs.dig("mutation-rust", "strategy", "matrix", "shard").size

    assert_includes commands("mutation-rust-score"), "bundle exec rake \"mutation:rust:score[#{shards}]\""
  end

  def test_should_build_the_rust_mutants_with_the_pinned_rust
    assert_includes commands("mutation-rust"), "rustup toolchain install"
  end

  private

  # YAML 1.1 reads the key `on` as true.
  def workflow = YAML.safe_load_file(WORKFLOW)
  def triggers = workflow.fetch(true)
  def jobs = workflow.fetch("jobs")
  def commands(job) = jobs.dig(job, "steps").filter_map { |step| step["run"] }
  def setup_ruby(job) = jobs.dig(job, "steps").find { |step| step["uses"].to_s.start_with?("ruby/setup-ruby") }
end
