# frozen_string_literal: true

require_relative "job_order"
require_relative "../jobs/standings"

module FunCi
  module Console
    # The job section's rows (design.md, The console): where each daily and
    # weekly job of the board's projects stands (Jobs::Standing), in JobOrder.
    class JobRows
      def initialize(db)
        @db = db
      end

      def of(projects, now:)
        standings = projects.flat_map { |project| Jobs::Standings.new(@db, project, now: now).all }
        JobOrder.of(standings, projects: projects)
      end
    end
  end
end
