# frozen_string_literal: true

module FunCi
  module Agent
    # What happened to a project's runs between two looks at them
    # (acceptance-tests.md, AT-9.16), oldest run first: a run started, each
    # stage that finished in the order it finished, a run that passed or
    # failed, a run a newer commit superseded, a check of its commit against
    # the trunk recorded or made again. The first look is at nothing.
    module Events
      # finished: [{ stage:, state:, seconds: }, ...] in the order they finished;
      # trunk: the latest check of its commit, as status --json gives it, or nil.
      RunState = Data.define(:id, :sha, :branch, :status, :finished, :superseded_by, :trunk)

      class RunState
        def initialize(trunk: nil, **) = super
      end
      OUTCOMES = { "completed" => "passed", "failed" => "failed" }.freeze
      FAILED_STATES = %w[failed over_budget].freeze

      # before, after: { run id => RunState }.
      def self.between(before, after)
        after.values.sort_by(&:id).flat_map { |run| of(run, before[run.id]) }
      end

      def self.failure?(event)
        return true if event[:event] == "run_superseded"

        event[:event] == "stage_finished" && FAILED_STATES.include?(event[:state])
      end

      def self.of(run, was)
        about = { commit: run.sha, branch: run.branch }
        [*(was ? [] : [{ event: "run_started", **about }]),
         *newly_finished(run, was).map { |stage| { event: "stage_finished", **about, **stage } },
         *checked(run, was, about), *ended(run, was, about)]
      end

      def self.newly_finished(run, was)
        seen = (was&.finished || []).map { |stage| stage[:stage] }
        run.finished.reject { |stage| seen.include?(stage[:stage]) }
      end

      # A check is new when its state or its trunk tip is.
      def self.checked(run, was, about)
        trunk = run.trunk
        return [] if trunk.nil? || trunk.values_at(:state, :sha) == was&.trunk&.values_at(:state, :sha)

        [{ event: "trunk_checked", **about, trunk: trunk }]
      end

      def self.ended(run, was, about)
        return [] if was&.status == run.status
        return [{ event: "run_superseded", **about, by_commit: run.superseded_by }] if run.status == "cancelled"

        OUTCOMES.key?(run.status) ? [{ event: "run_finished", **about, state: OUTCOMES.fetch(run.status) }] : []
      end
      private_class_method :of, :newly_finished, :checked, :ended
    end
  end
end
