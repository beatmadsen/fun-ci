# frozen_string_literal: true

module FunCi
  module Console
    # Runs of one project's branch cancelled one after another, as a rebase or
    # a burst of commits leaves them, as one: the newest of them, with
    # `folded:` saying how many it stands for (design.md, The console).
    module CancelledFolding
      # `runs` newest first, each run of cancelled ones folded into its newest.
      def self.fold(runs) = runs.slice_when { |newer, older| !one_stream?(newer, older) }.map { |group| kept(group) }

      def self.one_stream?(newer, older) = cancelled?(newer) && cancelled?(older) && key(newer) == key(older)
      def self.cancelled?(run) = run[:status] == "cancelled"
      def self.key(run) = [run[:project_path], run[:branch]]
      def self.kept(group) = group.size > 1 ? group.first.merge(folded: group.size) : group.first
      private_class_method :one_stream?, :cancelled?, :key, :kept
    end
  end
end
