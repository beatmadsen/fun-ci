# frozen_string_literal: true

require_relative "../jobs/state"

module FunCi
  module Agent
    # What happened to a project's daily and weekly job runs between two
    # looks at them (acceptance-tests.md, AT-13.23), oldest first: a job run
    # started, and ended with its state and seconds. The first look is at nothing.
    module JobEvents
      # state: as Jobs::State says it; seconds: how long it ran, once it ended.
      JobState = Data.define(:id, :job, :cadence, :sha, :branch, :state, :seconds)

      # The states of a run that has not ended.
      GOING = %w[running due].freeze

      # before, after: { job run id => JobState }.
      def self.between(before, after)
        after.values.sort_by(&:id).flat_map { |run| of(run, before[run.id]) }
      end

      def self.failure?(event) = event[:event] == "job_finished" && Jobs::State.needs_you?(event[:state])

      def self.of(run, was)
        about = { job: run.job, cadence: run.cadence, commit: run.sha, branch: run.branch }
        [*(was ? [] : [{ event: "job_started", **about }]), *ended(run, was, about)]
      end

      def self.ended(run, was, about)
        return [] if was&.state == run.state || GOING.include?(run.state)

        [{ event: "job_finished", **about, state: run.state, seconds: run.seconds }]
      end
      private_class_method :of, :ended
    end
  end
end
