# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/collector_kit"
require "json"

# What a stage over budget was doing, looked at before the kill (architecture.md, "Evidence of a failed stage").
class TestCollectorOverrun < Minitest::Test
  include CollectorKit

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
end
