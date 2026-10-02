# frozen_string_literal: true

require_relative "../jobs/state"

module FunCi
  module Agent
    # What happened to a project's daily and weekly job runs between two
    # looks at them (acceptance-tests.md, AT-13.23, AT-13.28), oldest first: a
    # job run was scheduled to start later (Jobs::Schedule), started, and
    # ended with its state and seconds. The first look is at nothing.
    module JobEvents
      # state: as Jobs::State says it; seconds: how long it ran, once it ended;
      # starts_at: when a run waiting its turn starts, nil for any other.
      JobState = Data.define(:id, :job, :cadence, :sha, :branch, :state, :seconds, :starts_at)

      # The states of a run that has not ended.
      GOING = %w[running due scheduled].freeze

      # before, after: { job run id => JobState }.
      def self.between(before, after)
        after.values.sort_by(&:id).flat_map { |run| of(run, before[run.id]) }
      end

      def self.failure?(event) = event[:event] == "job_finished" && Jobs::State.needs_you?(event[:state])

      def self.of(run, was)
        about = { job: run.job, cadence: run.cadence, commit: run.sha, branch: run.branch }
        [*begun(run, was, about), *ended(run, was, about)]
      end

      # A run first seen waiting was scheduled; one that started since the
      # last look started.
      def self.begun(run, was, about)
        return [{ event: "job_scheduled", **about, starts_at: run.starts_at }] if run.state == "scheduled" && !was

        started?(run, was) ? [{ event: "job_started", **about }] : []
      end

      # First seen past waiting, or past it now after it waited; one
      # cancelled while it waited never started.
      def self.started?(run, was)
        return false if run.state == "scheduled"
        return true unless was

        was.state == "scheduled" && run.state != "cancelled"
      end

      def self.ended(run, was, about)
        return [] if was&.state == run.state || GOING.include?(run.state)

        [{ event: "job_finished", **about, state: run.state, seconds: run.seconds }]
      end
      private_class_method :of, :begun, :started?, :ended
    end
  end
end
