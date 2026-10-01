# frozen_string_literal: true

module FunCi
  module Console
    # The order of the job section's rows (design.md, The console): what
    # needs you first, then running, due and passed; among equals, the
    # board's projects in its order, then each project's jobs by name. Rows
    # answer #state (Jobs::State), #project and #name.
    module JobOrder
      URGENCY = { "failed" => 0, "lost" => 0, "over_budget" => 1, "running" => 2, "due" => 3, "cancelled" => 3,
                  "passed" => 4 }.freeze
      # A state this fun-ci doesn't know, which a newer one sharing the database may have written.
      UNKNOWN = 5

      def self.of(rows, projects:)
        rows.sort_by do |row|
          [URGENCY.fetch(row.state, UNKNOWN), projects.index(row.project) || projects.size, row.name]
        end
      end
    end
  end
end
