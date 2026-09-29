# frozen_string_literal: true

require "json"
require_relative "../evidence/document"
require_relative "../persistence/stage_job"

module FunCi
  module Agent
    RunReport = Data.define(:sha, :subject, :branch, :need, :stages, :verdict, :deciding, :superseded_by, :trunk)

    # One stage of a run, as an agent is told it.
    class RunReport
      STATES = { "completed" => "passed", "timed_out" => "over_budget", "scheduled" => "waiting" }.freeze

      # What a failed stage left to explain itself: the end of its output,
      # and the failures it reported, each { file:, line:, test:, message: },
      # unless they were pruned; the evidence document, if it kept one; and
      # how many bytes of raw output are kept, if any.
      Kept = Data.define(:tail, :failures, :pruned, :evidence, :raw_bytes)

      class Kept
        def initialize(pruned: false, evidence: nil, raw_bytes: nil, **) = super

        def document
          evidence ? Evidence::Document.from_json(evidence) : Evidence::Document.legacy(tail: tail, failures: failures)
        end
      end

      NOTHING_KEPT = Kept.new(tail: nil, failures: [])

      # How a finished stage's process ended, and the budget it had.
      Exit = Data.define(:exit_status, :signal, :budget)
      NO_EXIT = Exit.new(exit_status: nil, signal: nil, budget: nil)

      # id: the stage's row, nil for a stage that hasn't started.
      Stage = Data.define(:name, :state, :seconds, :kept, :exit, :id)

      class Stage
        def initialize(kept: NOTHING_KEPT, exit: NO_EXIT, id: nil, **) = super
        def exit_status = exit.exit_status
        def signal = exit.signal
        def budget = exit.budget
        def evidence = kept.document
        def pruned? = kept.pruned
        def raw_bytes = kept.raw_bytes
        def tail = kept.tail
        # The failures its evidence names, from whichever extractor found them.
        def failures = evidence.failures.map { |failure| failure.except(:extractor) }

        def self.from_row(name, job)
          return new(name: name, state: "waiting", seconds: nil) unless job

          ended = Exit.new(exit_status: job[:exit_status], signal: job[:signal], budget: job[:budget])
          new(name: name, state: STATES.fetch(job[:status], job[:status]), seconds: seconds(job), id: job[:id],
              kept: kept(job), exit: ended)
        end

        def self.kept(job)
          failures = job[:failures] ? JSON.parse(job[:failures], symbolize_names: true) : []
          Kept.new(tail: job[:output_tail], failures: failures, pruned: job[:pruned] == 1, evidence: job[:evidence],
                   raw_bytes: job[:raw_bytes])
        end

        def self.seconds(job)
          Persistence::StageJob.elapsed_duration(job)&.round(1)
        end
        private_class_method :kept, :seconds
      end
    end
  end
end
