# frozen_string_literal: true

require "yaml"

module FunCi
  module Setup
    # .fun-ci/config: settings for this machine's runs, as YAML. Each one left
    # out takes its default; one that is wrong is reported and the default used,
    # as are all of them when the file isn't YAML.
    class Settings
      DEFAULTS = { "worktree_slots" => 2 }.freeze

      def initialize(path)
        @path = path
      end

      def worktree_slots = errors.empty? ? values.fetch("worktree_slots") : DEFAULTS.fetch("worktree_slots")

      def errors
        return [".fun-ci/config must be a mapping such as `worktree_slots: 2`"] unless raw.is_a?(Hash)

        slots = values["worktree_slots"]
        return [] if slots.is_a?(Integer) && slots.positive?

        [".fun-ci/config: worktree_slots must be a whole number above 0, not #{slots.inspect}"]
      rescue Psych::SyntaxError => e
        [".fun-ci/config is not YAML: #{e.problem} (line #{e.line})"]
      end

      private

      def raw = File.exist?(@path) ? YAML.safe_load_file(@path) || {} : {}
      def values = DEFAULTS.merge(raw)
    end
  end
end
