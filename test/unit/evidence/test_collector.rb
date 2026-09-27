# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/collector"
require "fun_ci/evidence/process_table"
require_relative "../../support/fake_stage_dir"

# What fun-ci keeps about a stage that failed (why.md, "How it fits together").
class TestCollector < Minitest::Test
  SOURCES = FunCi::Evidence::Sources
  SETTINGS = FunCi::Evidence::Settings
  GREP = { "use" => "grep", "patterns" => ["ERROR"] }.freeze
  OVERRUN_GREP = GREP.merge("on" => "overrun").freeze
  PROCESSES = [FunCi::Evidence::ProcessTable::Row.new(pid: 42, ppid: 1, pgid: 42, seconds: 9, command: "sh fast.sh"),
               FunCi::Evidence::ProcessTable::Row.new(pid: 43, ppid: 42, pgid: 42, seconds: 8, command: "java Worker")]
              .freeze

  # A clock that moves on a second each time it is read.
  class TickingClock
    def initialize = @now = 0
    def call = @now += 1
  end

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

  def test_should_mask_what_the_project_s_own_patterns_match
    assert_equal ["id [masked]"], collect("id ACME-1234\n", settings: { "mask" => ['ACME-\d+'] }).excerpts.first[:lines]
  end

  def test_should_keep_secrets_when_the_project_turns_masking_off
    assert_equal ["token abcdefgh123"], collect("token abcdefgh123\n", settings: { "masking" => false },
                                                                       environment: { "API_TOKEN" => "abcdefgh123" })
      .excerpts.first[:lines]
  end

  def test_should_name_the_stages_that_shared_the_slot_as_a_fact_of_fun_ci_s
    assert_equal [{ name: "alongside", value: "lint, slow", extractor: "fun-ci" }],
                 collector.collect("boom\n",
                                   FunCi::Evidence::Outcome.new(state: "failed", alongside: %w[lint slow])).facts
  end

  def test_should_say_nothing_of_stages_alongside_when_there_were_none
    assert_empty collector.collect("boom\n", FunCi::Evidence::Outcome.new(state: "failed")).facts
  end

  def test_should_say_what_an_overrun_stage_was_running_before_the_kill
    overrun = collector(processes: -> { PROCESSES }).before_kill(42)

    assert_equal [{ name: "running", value: "java Worker (8s)", extractor: "process-tree" }],
                 collector.collect("", FunCi::Evidence::Outcome.new(state: "over_budget", overrun: overrun)).facts
  end

  def test_should_run_the_entries_for_an_overrun_before_the_kill
    overrun = collector(settings: { "stages" => { "fast" => [OVERRUN_GREP] } }).before_kill(42)

    assert_equal(%w[process-tree grep], overrun.chosen.map { |chosen| chosen[:extractor] })
  end

  def test_should_leave_the_entries_for_an_overrun_out_of_the_evidence_of_a_failure
    assert_equal(%w[output-tail], collect("ERROR\n", entries: [OVERRUN_GREP]).excerpts.map { |e| e[:extractor] })
  end

  def test_should_mask_the_raw_output
    assert_equal "a [masked:API_TOKEN]\n",
                 collector(environment: { "API_TOKEN" => "abcdefgh123" }).masked("a abcdefgh123\n")
  end

  private

  def collect(output, entries: [], settings: {}, **given)
    collector(settings: settings.merge("stages" => { "fast" => entries }), **given).collect(output)
  end

  # given: the sources' reports, environment and worktree, where a test names them.
  def collector(settings: {}, clock: -> { 0 }, **given)
    sources = SOURCES.new(stage: "fast", worktree: "/slot-0", reports: FakeStageDir.new, environment: {}, **given)
    FunCi::Evidence::Collector.new(sources, settings: SETTINGS.new(settings), clock: clock)
  end
end
