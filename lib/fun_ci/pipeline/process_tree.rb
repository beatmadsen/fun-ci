# frozen_string_literal: true

module FunCi
  module Pipeline
    # What to kill besides a stage's process groups: each process descended
    # from one of their members, by parent id, that has left for a group or
    # session of its own, as Node's detached children do. The rows must be
    # read before the kill, since a killed parent's children move to init.
    # A double-forked daemon has moved to init already and is not reached.
    module ProcessTree
      # Signal targets: -pid for an escapee leading its own group, which
      # takes that group with it, and the pid alone of one in any other group.
      def self.escaped(groups, rows)
        escapees = outside(groups, descendants(in_groups(groups, rows), rows))
        leaders = escapees.select { |row| row.pgid == row.pid }.map(&:pid)
        leaders.map(&:-@) + escapees.reject { |row| leaders.include?(row.pgid) }.map(&:pid)
      end

      def self.in_groups(groups, rows) = rows.select { |row| groups.include?(row.pgid) }
      def self.outside(groups, rows) = rows.reject { |row| groups.include?(row.pgid) }

      # Bounded by the table's size, so a table whose parent ids form a cycle still ends.
      def self.descendants(found, rows)
        rows.size.times do
          more = children(found.map(&:pid), rows) - found
          return found if more.empty?

          found += more
        end
        found
      end

      def self.children(parents, rows) = rows.select { |row| parents.include?(row.ppid) }
      private_class_method :in_groups, :outside, :descendants, :children
    end
  end
end
