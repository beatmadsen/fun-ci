# frozen_string_literal: true

module FunCi
  module Console
    # The milestones a run has reached, in the order it reached them
    # (design.md, A run's states): its stages in the order they finished (a
    # stage recorded before that order was kept counts as unordered, and lint,
    # build, fast is the fallback), then the run passing or failing.
    module Milestones
      STAGES = %w[lint build fast].freeze
      OUTCOMES = { "completed" => ["run_passed"], "failed" => ["run_failed"] }.freeze

      def self.of(run)
        passed = run[:stages].select { |stage| stage[:status] == "completed" && STAGES.include?(stage[:stage]) }
        passed.sort_by { |stage| order(stage) }.map { |stage| "#{stage[:stage]}_passed" } +
          OUTCOMES.fetch(run[:status], [])
      end

      def self.order(stage)
        [stage[:finished_order].to_i, STAGES.index(stage[:stage])]
      end
      private_class_method :order
    end
  end
end
