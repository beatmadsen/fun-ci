# frozen_string_literal: true

require "time"
require_relative "about"

module FunCi
  module Evidence
    # What is known About a stage, from what was known when it started and
    # how it ended. Its output is written to its directory for a project's
    # command to read.
    module AboutStage
      def self.of(sources, outcome, output)
        About.new(**outcome.to_h.except(:overrun), **started(sources), **where(sources, output),
                  stage: sources.stage, budget: sources.budget, commit: sources.commit)
      end

      def self.where(sources, output)
        { worktree: sources.worktree, output: sources.reports.output_file(output),
          reports: sources.reports.reports_path }
      end

      def self.started(sources)
        return { seconds: nil, started_at: nil } unless sources.started

        { seconds: (Time.now - sources.started).round(1), started_at: sources.started.utc.iso8601(3) }
      end
      private_class_method :started, :where
    end
  end
end
