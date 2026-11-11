# frozen_string_literal: true

module FunCi
  module Persistence
    # The tables where the console keeps the rows the user hid, per machine
    # (architecture.md, Daily and weekly jobs): JobVisibility's and BranchVisibility's.
    module HiddenRowTables
      JOBS = <<~SQL
        CREATE TABLE IF NOT EXISTS hidden_jobs (
          project_path TEXT, job TEXT, kind TEXT, hidden_at TEXT,
          PRIMARY KEY (project_path, job)
        )
      SQL

      BRANCHES = <<~SQL
        CREATE TABLE IF NOT EXISTS hidden_branches (
          project_path TEXT, branch TEXT, kind TEXT, hidden_at TEXT, PRIMARY KEY (project_path, branch)
        )
      SQL

      ALL = [JOBS, BRANCHES].freeze
    end
  end
end
