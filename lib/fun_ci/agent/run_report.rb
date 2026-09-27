# frozen_string_literal: true

require_relative "verdict"
require_relative "report_stage"

module FunCi
  module Agent
    # What an agent is told about one run: its commit, each of the four stages
    # in pipeline order, and the verdict for the level it needs.
    class RunReport
      STAGES = %w[lint build fast slow].freeze

      # deciding: the stage whose failure or overrun decided the verdict, if one did.
      def initialize(deciding: nil, **) = super

      # commit: the run's subject and the commit that superseded it, if any.
      def self.build(run:, jobs:, need:, commit:)
        verdict = Verdict.decide(run_status: run[:status], stages: jobs, need: need)
        new(sha: run[:commit_hash], branch: run[:branch], need: need, stages: stages(jobs), verdict: verdict,
            deciding: Verdict.deciding_stage(stages: jobs, need: need), **commit)
      end

      # The four stages in pipeline order, from the run's stage rows.
      def self.stages(jobs)
        by_name = jobs.to_h { |job| [job[:stage], job] }
        STAGES.map { |name| Stage.from_row(name, by_name[name]) }
      end
    end
  end
end
