# frozen_string_literal: true

require_relative "job_order"
require_relative "job_row"
require_relative "../jobs/standings"
require_relative "../persistence/job_visibility"

module FunCi
  module Console
    # The job section's rows (design.md, The console): where each daily and
    # weekly job of the board's projects stands (Jobs::Standing) and how the
    # user hid it, if they did (Persistence::JobVisibility), in JobOrder.
    class JobRows
      def initialize(db)
        @db = db
      end

      def of(projects, now:)
        JobOrder.of(projects.flat_map { |project| rows_of(project, now) }, projects: projects)
      end

      private

      def rows_of(project, now)
        hidden = Persistence::JobVisibility.new(@db).hidden(project)
        Jobs::Standings.new(@db, project, now: now).all.map do |standing|
          JobRow.new(standing: standing, hidden: hidden[standing.name])
        end
      end
    end
  end
end
