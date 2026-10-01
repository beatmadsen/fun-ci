# frozen_string_literal: true

require "shellwords"

module FunCi
  module Jobs
    # A script a project runs at most once a day or once a week, named after
    # it (design.md, Daily and weekly jobs). `cadence` is "daily" or "weekly".
    Job = Data.define(:name, :cadence, :script)

    class Job
      PERIODS = { "daily" => 86_400, "weekly" => 604_800 }.freeze
      # Every job's, the weekly ones' too.
      BUDGET = 86_400
      # How a job is named where a stage would be.
      STAGE = "jobs/"

      # The name of the job a stage name names, or nil for a pipeline stage's.
      def self.named_by(stage) = (stage.delete_prefix(STAGE) if stage.start_with?(STAGE))

      # Seconds from one run's start until the job is due again.
      def period = PERIODS.fetch(cadence)

      # What evidence knows it by: `evidence: jobs: <name>:` in .fun-ci/config.
      def stage = "#{STAGE}#{name}"

      # The shell command that runs it on a commit, its path quoted.
      def command(sha) = "#{Shellwords.escape(script)} #{sha}"
    end
  end
end
