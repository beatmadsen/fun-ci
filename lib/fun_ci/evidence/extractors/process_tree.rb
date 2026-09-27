# frozen_string_literal: true

require_relative "../findings"

module FunCi
  module Evidence
    module Extractors
      # `process-tree`: for a stage that ran over budget, before the kill, the
      # processes of its group as a tree, each with how long it had run, and
      # the deepest one as the fact `running` (architecture.md, "Evidence of a failed stage").
      class ProcessTree
        OPTIONS = {}.freeze
        REQUIRED = [].freeze

        def initialize(options)
          @options = options
        end

        def extract(context)
          return Findings.new unless context.pgid

          group = context.processes.call.select { |row| row.pgid == context.pgid }
          return Findings.new if group.empty?

          Findings.new(facts: [running(group)], excerpts: [tree(group)])
        end

        private

        def depth(row, group) = (parent = group.find { |other| other.pid == row.ppid }) ? depth(parent, group) + 1 : 0

        def running(group)
          deepest = group.max_by { |row| [depth(row, group), -row.seconds] }
          { name: "running", value: "#{deepest.command} (#{deepest.seconds}s)" }
        end

        def tree(group)
          lines = ordered(group, group.reject { |row| group.any? { |other| other.pid == row.ppid } }, 0)
          { title: "Processes still running at the kill", location: "ps", lines: lines }
        end

        def ordered(group, rows, level)
          rows.sort_by(&:pid).flat_map do |row|
            ["#{"  " * level}#{row.pid} #{row.seconds}s #{row.command}",
             *ordered(group, group.select { |child| child.ppid == row.pid }, level + 1)]
          end
        end
      end
    end
  end
end
