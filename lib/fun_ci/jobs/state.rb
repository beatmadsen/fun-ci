# frozen_string_literal: true

module FunCi
  module Jobs
    # A job's state, read once from its latest run as job_runs keeps it
    # (design.md, Daily and weekly jobs): `due` while it never ran, then
    # `scheduled` while it waits its turn to start (Schedule), `running`,
    # `passed`, `failed`, `over_budget`, `cancelled`, or `lost`
    # when its process died before it said how the run ended. Each surface
    # (the console, the agent commands) says these in its own words.
    module State
      OF_STATUS = { "completed" => "passed", "failed" => "failed", "timed_out" => "over_budget",
                    "running" => "running", "scheduled" => "scheduled", "cancelled" => "cancelled" }.freeze
      NEEDS_YOU = %w[failed over_budget lost].freeze

      # run: { status:, completed_at: }, or nil when the job never ran.
      def self.of(run)
        return "due" unless run
        return "lost" if run[:status] == "failed" && run[:completed_at].nil?

        OF_STATUS.fetch(run[:status], "unknown")
      end

      def self.needs_you?(state) = NEEDS_YOU.include?(state)
    end
  end
end
