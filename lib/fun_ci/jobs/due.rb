# frozen_string_literal: true

require "time"

module FunCi
  module Jobs
    # Whether a job is due, from its latest run alone ({ status:, started_at: },
    # or nil when it never ran): when it never ran, when that run was
    # cancelled, or a period after that run started, unless it still runs or
    # waits to (design.md, Daily and weekly jobs).
    class Due
      def initialize(latest, period, now:)
        @latest = latest
        @period = period
        @now = now
      end

      def now?
        return true if @latest.nil? || @latest[:status] == "cancelled"

        !running? && again <= @now
      end

      # When it is due again, or nil while it is due now or still runs.
      def at = now? || running? ? nil : again

      private

      # A run waiting its turn (Schedule) counts as running: it is the job's run.
      def running? = %w[running scheduled].include?(@latest[:status])
      def again = Time.parse(@latest[:started_at]) + @period
    end
  end
end
