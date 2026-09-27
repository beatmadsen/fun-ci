# frozen_string_literal: true

require "time"
require_relative "verdict"

module FunCi
  module Agent
    # What an agent is told about one run: its commit, each of the four stages
    # in pipeline order, and the verdict for the level it needs.
    RunReport = Data.define(:sha, :subject, :branch, :need, :stages, :verdict, :superseded_by)

    class RunReport
      STAGES = %w[lint build fast slow].freeze
      STATES = { "completed" => "passed", "timed_out" => "over_budget", "scheduled" => "waiting" }.freeze
      # tail: the end of what the stage printed, kept when it failed.
      Stage = Data.define(:name, :state, :seconds, :tail)

      class Stage
        def initialize(name:, state:, seconds:, tail: nil) = super
      end

      # commit: the run's subject and the commit that superseded it, if any.
      def self.build(run:, jobs:, need:, commit:)
        verdict = Verdict.decide(run_status: run[:status], stages: jobs, need: need)
        new(sha: run[:commit_hash], branch: run[:branch], need: need, stages: stages(jobs), verdict: verdict, **commit)
      end

      def self.stages(jobs)
        by_name = jobs.to_h { |job| [job[:stage], job] }
        STAGES.map { |name| stage(name, by_name[name]) }
      end

      def self.stage(name, job)
        return Stage.new(name: name, state: "waiting", seconds: nil) unless job

        state = STATES.fetch(job[:status], job[:status])
        Stage.new(name: name, state: state, seconds: seconds(job), tail: job[:output_tail])
      end

      def self.seconds(job)
        return nil unless job[:started_at] && job[:completed_at]

        (Time.parse(job[:completed_at]) - Time.parse(job[:started_at])).round(1)
      end
      private_class_method :stages, :stage, :seconds
    end
  end
end
