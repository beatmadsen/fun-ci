# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../contract/capture/golden_corpus"

# AT-2.6: the golden corpus pins what today's Ruby renderer draws, frame by
# frame, for every scenario the Rust renderer must later match.
class TestGoldenCorpus < Minitest::Test
  SCENARIOS = %w[empty happy-7 running fail-explosion success-fireworks
                 narrow-60 wide-200 resize-mid-animation].freeze
  RUN_STATUSES = %w[pending running passed failed timeout cancelled].freeze
  STAGE_STATUSES = %w[pending running passed failed cancelled timeout].freeze

  def test_the_corpus_has_exactly_the_eight_specified_scenarios
    assert_equal SCENARIOS.sort, corpus.scenario_names.sort
  end

  def test_the_scenarios_between_them_use_every_run_status
    assert_equal RUN_STATUSES.sort, statuses_used { |run| [run["status"]] }
  end

  def test_the_scenarios_between_them_use_every_stage_status
    assert_equal STAGE_STATUSES.sort, statuses_used { |run| run["stages"].map { |s| s["status"] } }
  end

  SCENARIOS.each do |name|
    define_method("test_the_ruby_renderer_still_draws_the_golden_frames_of_#{name.tr("-", "_")}") do
      golden = corpus.golden(name)
      frame = first_difference(corpus.capture(name), golden)

      refute_empty golden
      assert_nil frame, "#{name}: frame #{frame} differs from contract/golden/#{name}/ (rake contract:capture rewrites it)"
    end
  end

  private

  def corpus
    FunCi::Contract::GoldenCorpus.new(root: File.expand_path("../../contract", __dir__))
  end

  def statuses_used(&)
    corpus.scenario_names.flat_map { |name| boards(name).flat_map { |b| b["runs"].flat_map(&) } }.uniq.sort
  end

  def boards(name)
    corpus.messages(name).select { |m| m["t"] == "board" }
  end

  def first_difference(captured, golden)
    (0...[captured.size, golden.size].max).find { |i| captured[i] != golden[i] }&.succ
  end
end
