# frozen_string_literal: true

require_relative "../test_helper"
require "rake"

# AT-0.3: a lane nobody runs rots. The gate (`rake default`) runs exactly the
# lanes CLAUDE.md lists under Lanes; every other rake task the docs mention
# either runs a subset of `rake test` or is listed under Tools.
class TestGateLanes < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  RAKE = Rake::Application.new.tap do |app|
    Rake.application = app
    Rake.load_rakefile(File.join(ROOT, "Rakefile"))
  end

  def test_the_gate_runs_exactly_the_lanes_claude_md_lists
    assert_equal section("Lanes"), RAKE[:default].prerequisites
  end

  def test_every_documented_rake_task_is_a_gate_lane_a_subset_of_the_test_lane_or_a_tool
    unrun = documented_tasks - section("Lanes") - section("Tools") - test_subsets

    assert_empty unrun
  end

  private

  def section(name)
    File.read(File.join(ROOT, "CLAUDE.md")).split(/^### /).find { |part| part.start_with?("#{name}\n") }
        .to_s.scan(/^(?:bundle exec )?rake (\S+)/).flatten
  end

  def documented_tasks
    %w[CLAUDE.md README.md].flat_map { |doc| File.read(File.join(ROOT, doc)).scan(/^(?:bundle exec )?rake (\S+)/) }
                           .flatten.uniq
  end

  def test_subsets
    TEST_LANES.keys.select { |lane| (test_files(lane) - test_files("test")).empty? }
  end

  def test_files(lane) = Dir.glob(TEST_LANES.fetch(lane), base: ROOT)
end
