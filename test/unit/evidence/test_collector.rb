# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/collector"
require_relative "../../support/fake_stage_dir"

# What fun-ci keeps about a stage that failed (why.md, "How it fits together").
class TestCollector < Minitest::Test
  SOURCES = FunCi::Evidence::Sources

  def test_should_credit_the_failures_the_stage_reported_to_test_reports
    reports = FakeStageDir.new([{ file: "a.rb", line: 3, test: "t", message: "m" }])

    assert_equal [{ file: "a.rb", line: 3, test: "t", message: "m", extractor: "test-reports" }],
                 collect("", reports: reports).failures
  end

  def test_should_keep_the_output_s_last_lines_without_colour
    assert_equal %w[boom], collect("\e[31mboom\e[0m\n").excerpts.first[:lines]
  end

  def test_should_mask_the_value_of_a_secret_in_the_stage_s_environment
    assert_equal ["token [masked:API_TOKEN]"],
                 collect("token abcdefgh123\n", environment: { "API_TOKEN" => "abcdefgh123" }).excerpts.first[:lines]
  end

  def test_should_mask_a_secret_the_size_cap_would_cut_in_two
    output = "#{"x" * 10}abcdefgh123#{"y" * 65_530}\n"

    kept = collect(output, environment: { "API_TOKEN" => "abcdefgh123" }).excerpts.first[:lines].join

    assert_equal 0, kept.scan("h123").size
  end

  def test_should_mask_the_raw_output
    sources = SOURCES.new(stage: "fast", worktree: "/slot-0", reports: FakeStageDir.new,
                          environment: { "API_TOKEN" => "abcdefgh123" })

    assert_equal "a [masked:API_TOKEN]\n", FunCi::Evidence::Collector.new(sources).masked("a abcdefgh123\n")
  end

  private

  def collect(output, reports: FakeStageDir.new, environment: {})
    sources = SOURCES.new(stage: "fast", worktree: "/slot-0", reports: reports, environment: environment)
    FunCi::Evidence::Collector.new(sources).collect(output)
  end
end
