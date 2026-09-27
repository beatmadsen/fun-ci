# frozen_string_literal: true

module FunCi
  module Agent
    # What a run means for the level an agent needs (acceptance-tests.md,
    # §9): the stages it needs decide, in the order they finished, and a
    # cancelled run is superseded only while they haven't.
    module Verdict
      LEVELS = { "build" => %w[lint build], "fast" => %w[lint build fast], "all" => %w[lint build fast slow] }.freeze
      FINISHED_BADLY = { "failed" => :failed, "timed_out" => :over_budget }.freeze

      def self.decide(run_status:, stages:, need:)
        needed = stages.select { |stage| LEVELS.fetch(need).include?(stage[:stage]) }
        first_bad = first_finished_badly(needed)
        return FINISHED_BADLY.fetch(first_bad[:status]) if first_bad
        return :passed if needed.count { |stage| stage[:status] == "completed" } == LEVELS.fetch(need).size

        run_status == "cancelled" ? :superseded : :undecided
      end

      def self.first_finished_badly(stages)
        stages.select { |stage| FINISHED_BADLY.key?(stage[:status]) }.min_by { |stage| stage[:finished_order] }
      end
      private_class_method :first_finished_badly
    end
  end
end
