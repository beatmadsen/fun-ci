# frozen_string_literal: true

require "time"

module FunCi
  module Console
    # A run as BoardData reads it from SQLite, as the protocol's `board`
    # message carries it: protocol status names, epoch seconds and
    # milliseconds. Formatting them is the renderer's job.
    module RunMessage
      STATUS = { "scheduled" => "pending", "completed" => "passed", "timed_out" => "timeout" }.freeze

      def self.from(run)
        { id: run[:id], sha: run[:commit_hash], branch: run[:branch], project: run[:project_path],
          status: status(run[:status]), started_at: epoch(run[:created_at]), updated_at: epoch(run[:updated_at]),
          stages: run[:stages].map { |stage| stage(stage) } }.compact
      end

      def self.stage(stage)
        { stage: stage[:stage], status: status(stage[:status]),
          duration_ms: stage[:duration] && (stage[:duration] * 1000).round,
          started_at: (epoch(stage[:started_at]) if stage[:status] == "running") }.compact
      end
      private_class_method :stage

      def self.status(name) = STATUS.fetch(name, name)
      private_class_method :status

      def self.epoch(iso) = iso && Time.parse(iso).to_i
      private_class_method :epoch
    end
  end
end
