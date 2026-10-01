# frozen_string_literal: true

module FunCi
  module Console
    # The order of the job section's rows (design.md, The console): what
    # needs you first, then running, due and passed; among equals, the
    # board's projects in its order, then each project's jobs by name.
    module JobOrder
      URGENCY = { "failed" => 0, "timed_out" => 1, "running" => 2, "due" => 3, "completed" => 4 }.freeze

      def self.of(rows, projects:)
        rows.sort_by { |row| [URGENCY.fetch(row[:status]), projects.index(row[:project]) || projects.size, row[:name]] }
      end
    end
  end
end
