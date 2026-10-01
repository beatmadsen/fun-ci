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

      # Seconds from one run's start until the job is due again.
      def period = PERIODS.fetch(cadence)

      # The shell command that runs it on a commit, its path quoted.
      def command(sha) = "#{Shellwords.escape(script)} #{sha}"
    end
  end
end
