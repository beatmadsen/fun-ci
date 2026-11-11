# frozen_string_literal: true

require_relative "scenario"

module Screenshots
  # A daily or weekly job whose latest run ended `ago` seconds before the
  # board's clock, due again in half a day.
  Job = Data.define(:name, :cadence, :status, :branch, :ago) do
    def to_h(now)
      { project: "/src/shop", name:, cadence:, status:, run_id: name.sum, sha: Digest::SHA1.hexdigest(name),
        branch:, started_at: now - ago - 600, updated_at: now - ago, due_at: now + 43_200 }
    end
  end

  # A run of the project the jobs belong to, as Ruby names it on each run.
  Shop = Data.define(:run) do
    def to_h(now) = run.to_h(now).merge(project: "/src/shop")
  end

  # A branch's run or a job the user hid, shown once they asked to see the
  # hidden rows: `how` is snoozed or ignored.
  Hidden = Data.define(:row, :how) do
    def to_h(now) = row.to_h(now).merge(hidden: how)
  end

  # Hiding rows in the console: an abandoned branch's old failure ignored, a
  # failing soak job snoozed until its next run, then the hidden rows shown.
  module Hiding
    SPIKE = Shop.new(Run.of(8, "spike/old-cache", "lint:0.4 build:1.3 fast:fail@2.6 slow:44", ago: 260_000))
    PASSED = [
      Run.of(12, "main", "lint:0.4 build:1.3 fast:2.1 slow:48", ago: 900),
      Run.of(11, "feature/search", "lint:0.5 build:1.4 fast:2.3 slow:51", ago: 1500),
      Run.of(10, "docs/readme", "lint:0.4 build:1.3 fast:2.0 slow:49", ago: 3600)
    ].map { |run| Shop.new(run) }.freeze
    SOAK = Job.new("soak", "weekly", "failed", "main", 90_000)
    AUDIT = Job.new("deps-audit", "daily", "passed", "main", 30_000)
    # Each step: the runs, the jobs, the cursor and question, and how many ticks it shows.
    STEPS = [
      [[SPIKE, *PASSED], [SOAK, AUDIT], { cursor: 0 }, 16],
      [[SPIKE, *PASSED], [SOAK, AUDIT], { cursor: 0, hiding: true }, 24],
      [PASSED, [SOAK, AUDIT], { cursor: 0, hidden_rows: 1 }, 12],
      [PASSED, [SOAK, AUDIT], { cursor: 3, hidden_rows: 1 }, 10],
      [PASSED, [SOAK, AUDIT], { cursor: 3, hiding: true, hidden_rows: 1 }, 24],
      [PASSED, [AUDIT], { cursor: 3, hidden_rows: 2 }, 16],
      [[Hidden.new(SPIKE, "ignored"), *PASSED], [AUDIT, Hidden.new(SOAK, "snoozed")], { cursor: 4, hidden_rows: 2 },
       30]
    ].freeze

    # Wide enough for the question to say how long each answer hides the row.
    COLS = 120

    def self.scenario
      scenario = Scenario.new(cols: COLS, rows: 34)
      STEPS.each_with_index do |(runs, jobs, view, ticks), index|
        scenario.board(runs, jobs:, streak: 3, **view)
        scenario.event("pin", run_id: 12, animation: "snowfall") if index.zero?
        scenario.ticks(ticks)
      end
      scenario
    end
  end
end
