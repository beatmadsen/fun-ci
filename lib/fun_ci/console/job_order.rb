# frozen_string_literal: true

module FunCi
  module Console
    # The order of the job section's rows (design.md, The console): what
    # needs you first, then running, waiting its turn to (Jobs::Schedule),
    # due and passed; among equals, the
    # board's projects in its order, then each project's jobs by name. A
    # hidden job, shown because the user asked, comes after every job in
    # view. Rows answer #state (Jobs::State), #project, #name and #hidden.
    module JobOrder
      URGENCY = { "failed" => 0, "lost" => 0, "over_budget" => 1, "running" => 2, "scheduled" => 3, "due" => 4,
                  "cancelled" => 4, "passed" => 5 }.freeze
      # A state this fun-ci doesn't know, which a newer one sharing the database may have written.
      UNKNOWN = 6

      def self.of(rows, projects:)
        rows.sort_by do |row|
          [row.hidden ? 1 : 0, URGENCY.fetch(row.state, UNKNOWN), projects.index(row.project) || projects.size,
           row.name]
        end
      end
    end
  end
end
