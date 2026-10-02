# frozen_string_literal: true

require "time"

module FunCi
  module Console
    # Where a job stands (Jobs::Standing) as the protocol's `board` carries it
    # under `jobs`: protocol status names and epoch seconds. Formatting them
    # is the renderer's job.
    module JobMessage
      # The protocol's word for a Jobs::State, where it has one of its own:
      # a cancelled job is due again, and one it can't read is shown due.
      STATUS = { "over_budget" => "timeout", "cancelled" => "due", "unknown" => "due" }.freeze

      def self.from(standing)
        { project: standing.project, name: standing.name, cadence: standing.cadence,
          status: STATUS.fetch(standing.state, standing.state), **run(standing.run, standing.starts_at),
          due_at: standing.due_at&.to_i }.compact
      end

      # What the latest run says: which, on what, and when; a run waiting its
      # turn (Jobs::Schedule) has not started, and says when it starts.
      def self.run(run, starts_at)
        return {} unless run

        { run_id: run[:id], sha: run[:commit_hash], branch: run[:branch], **times(run, starts_at) }
      end

      def self.times(run, starts_at)
        return { starts_at: starts_at.to_i } if starts_at

        { started_at: epoch(run[:started_at]), updated_at: epoch(run[:completed_at] || run[:started_at]) }
      end

      def self.epoch(iso) = Time.parse(iso).to_i
      private_class_method :run, :times, :epoch
    end
  end
end
