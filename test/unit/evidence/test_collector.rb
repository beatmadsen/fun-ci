# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/collector_kit"
require "json"

# What fun-ci keeps about a stage that failed (why.md, "How it fits together").
class TestCollector < Minitest::Test
  include CollectorKit

  def test_should_credit_the_failures_the_stage_reported_to_test_reports
    reports = FakeStageDir.new([{ file: "a.rb", line: 3, test: "t", message: "m" }])

    assert_equal [{ file: "a.rb", line: 3, test: "t", message: "m", extractor: "test-reports" }],
                 collect("", reports: reports).failures
  end

  def test_should_keep_the_output_s_last_lines_without_colour
    assert_equal %w[boom], collect("\e[31mboom\e[0m\n").excerpts.first[:lines]
  end

  def test_should_credit_a_configured_entry_s_excerpt_to_it
    assert_equal "grep", collect("ERROR one\n", entries: [GREP]).excerpts.first[:extractor]
  end

  def test_should_put_configured_excerpts_before_the_output_s_last_lines
    assert_equal(%w[grep output-tail], collect("ERROR one\n", entries: [GREP]).excerpts.map { |e| e[:extractor] })
  end

  def test_should_say_it_chose_a_configured_entry_because_it_was_configured
    assert_equal [{ extractor: "grep", because: "configured" }], collect("ERROR\n", entries: [GREP]).chosen
  end

  def test_should_record_a_mistaken_entry_as_a_problem
    assert_equal [{ extractor: "nosuch", message: "unknown extractor 'nosuch'" }],
                 collect("ERROR\n", entries: [{ "use" => "nosuch" }, GREP]).problems
  end

  def test_should_run_the_other_entries_when_one_is_mistaken
    assert_equal(%w[grep output-tail],
                 collect("ERROR\n", entries: [{ "use" => "nosuch" }, GREP]).excerpts.map { |e| e[:extractor] })
  end

  def test_should_record_an_entry_that_raises_as_a_problem
    entry = { "use" => "grep", "patterns" => ["ERROR"], "path" => "no/such.log" }

    assert_equal(["grep"], collect("", entries: [entry], worktree: Dir.tmpdir).problems.map { |p| p[:extractor] })
  end

  def test_should_skip_an_entry_once_the_budget_has_run_out
    problems = collect("ERROR\n", entries: [GREP, GREP], settings: { "budget" => 2 }, clock: TickingClock.new).problems

    assert_equal [{ extractor: "grep", message: "not run: the evidence budget of 2.0s ran out" }], problems
  end

  def test_should_name_the_stages_that_shared_the_slot_as_a_fact_of_fun_ci_s
    assert_equal [{ name: "alongside", value: "lint, slow", extractor: "fun-ci" }],
                 collector.collect("boom\n",
                                   FunCi::Evidence::Outcome.new(state: "failed", alongside: %w[lint slow])).facts
  end

  def test_should_say_nothing_of_stages_alongside_when_there_were_none
    assert_empty collector.collect("boom\n", FunCi::Evidence::Outcome.new(state: "failed")).facts
  end

  def test_should_run_a_detected_preset_after_the_configured_entries
    rspec = FunCi::Evidence::Detection::Found.new(preset: FunCi::Evidence::Presets.fetch("rspec"), because: "Gemfile")
    output = "Failures:\n  1) boom\nFinished in 1s\nrspec ./spec/a_spec.rb:4\n"
    found = collect(output, entries: [{ "use" => "grep", "patterns" => ["boom"] }], candidates: [rspec])

    assert_equal(%w[grep section:rspec output-tail], found.excerpts.map { |excerpt| excerpt[:extractor] })
  end

  def test_should_keep_the_evidence_within_its_size
    output = "ERROR #{"x" * 94}\n" * 4000

    assert_operator JSON.generate(collect(output, entries: [GREP]).to_h).bytesize, :<=, 262_144
  end

  # Ruby 3.2 and later memoise the classic ^(a+)+$, which then never times

  # out; the back-reference keeps this one backtracking on every Ruby in CI.

  def test_should_record_a_pattern_that_runs_out_of_time_as_a_problem_of_its_entry
    entry = { "use" => "grep", "patterns" => ['^(a+)+\1$'] }

    assert_match(/Regexp::TimeoutError/, collect("#{"a" * 40}!\n", entries: [entry]).problems.first[:message])
  end
end
