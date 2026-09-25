# frozen_string_literal: true

require "time"

module FunCi
  module Contract
    # Translates a protocol v1 run into the hash the 1.x Ruby renderer reads.
    module ProtocolRun
      RUN_STATUS = { "pending" => "scheduled", "passed" => "completed", "timeout" => "timed_out" }.freeze
      STAGE_STATUS = { "passed" => "completed", "timeout" => "timed_out" }.freeze

      def self.to_tui(run)
        { id: run["id"], commit_hash: run["sha"], branch: run["branch"],
          project_path: run["project"], status: RUN_STATUS.fetch(run["status"], run["status"]),
          updated_at: iso(run["updated_at"]), stages: run["stages"].map { |s| stage(s) } }
      end

      def self.stage(stage)
        { stage: stage["stage"], status: STAGE_STATUS.fetch(stage["status"], stage["status"]),
          duration: stage["duration_ms"]&./(1000.0), started_at: iso(stage["started_at"]) }
      end
      private_class_method :stage

      def self.iso(epoch)
        epoch && Time.at(epoch).utc.iso8601
      end
      private_class_method :iso
    end
  end
end
