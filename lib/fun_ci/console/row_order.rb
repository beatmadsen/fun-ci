# frozen_string_literal: true

module FunCi
  module Console
    # The order of the console's rows (design.md, The console): a project's
    # branches together, the project that most needs you first, and within it
    # the branch that most needs you first, newest first among equals. Ruby
    # decides it, since the cursor moves through the rows in this order.
    module RowOrder
      URGENCY = { "failed" => 0, "timed_out" => 1, "running" => 2, "scheduled" => 3, "completed" => 4 }.freeze
      # A conflict with the trunk needs you as much as a timeout.
      CONFLICT = 1
      LEAST = 5

      # `rows`, one per branch and newest first, in the order the console shows them.
      def self.of(rows)
        projects = rows.group_by { |row| row[:project_path] }.values
        projects.sort_by.with_index { |branches, i| [most(branches), i] }.flat_map { |branches| ordered(branches) }
      end

      def self.ordered(branches) = branches.sort_by.with_index { |row, i| [urgency(row), i] }
      def self.most(branches) = branches.map { |row| urgency(row) }.min

      def self.urgency(row)
        by_status = URGENCY.fetch(row[:status], LEAST)
        row.dig(:trunk, :branch_state) == "conflicts" ? [by_status, CONFLICT].min : by_status
      end
      private_class_method :ordered, :most, :urgency
    end
  end
end
