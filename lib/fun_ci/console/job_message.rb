# frozen_string_literal: true

require "time"

module FunCi
  module Console
    # A job row (JobRows) as the protocol's `board` carries it under `jobs`:
    # protocol status names and epoch seconds. Formatting them is the renderer's job.
    module JobMessage
      STATUS = { "completed" => "passed", "timed_out" => "timeout" }.freeze

      def self.from(row)
        { project: row[:project], name: row[:name], cadence: row[:cadence],
          status: STATUS.fetch(row[:status], row[:status]), **run(row[:run]), due_at: row[:due_at]&.to_i }.compact
      end

      # What the latest run says: which, on what, and when.
      def self.run(run)
        return {} unless run

        { run_id: run[:id], sha: run[:commit_hash], branch: run[:branch], started_at: epoch(run[:started_at]),
          updated_at: epoch(run[:completed_at] || run[:started_at]) }
      end

      def self.epoch(iso) = Time.parse(iso).to_i
      private_class_method :run, :epoch
    end
  end
end
