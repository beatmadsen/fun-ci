# frozen_string_literal: true

require "yaml"

module FunCi
  module Setup
    # .fun-ci/config: settings for this machine's runs, as YAML. Each one left
    # out takes its default; one that is wrong is reported and the default used,
    # as are all of them when the file can't be read as YAML. Anchors and
    # aliases are YAML, so they are read.
    class Settings
      DEFAULTS = { "worktree_slots" => 2 }.freeze
      FETCH_EVERY = 300
      UNITS = { "" => 1, "s" => 1, "m" => 60, "h" => 3600 }.freeze

      # The settings in the file at `path`, which may not exist.
      def self.at(path) = new(File.exist?(path) ? File.read(path) : nil)

      # text: the YAML, or nil for none.
      def initialize(text)
        @text = text
      end

      def worktree_slots = errors.empty? ? values.fetch("worktree_slots") : DEFAULTS.fetch("worktree_slots")

      # The trunk's name, or nil when none is given or it is no name. A mistake
      # in the trunk settings never stops a pipeline, so none is among `errors`.
      def trunk
        given = setting("trunk")
        given.is_a?(String) ? given : nil
      end

      # Seconds between fetches of the trunk, or nil when fun-ci doesn't fetch it.
      def trunk_fetch
        given = setting("trunk_fetch")
        return nil if given == false

        seconds(given) || FETCH_EVERY
      end

      def errors
        setting_errors
      rescue Psych::SyntaxError => e
        [".fun-ci/config is not YAML: #{e.problem} (line #{e.line})"]
      rescue Psych::Exception => e
        [".fun-ci/config can't be read: #{e.message}"]
      end

      private

      def setting_errors
        return [".fun-ci/config must be a mapping such as `worktree_slots: 2`"] unless raw.is_a?(Hash)

        slots = values["worktree_slots"]
        return [] if slots.is_a?(Integer) && slots.positive?

        [".fun-ci/config: worktree_slots must be a whole number above 0, not #{slots.inspect}"]
      end

      def setting(key)
        raw.is_a?(Hash) ? raw[key] : nil
      rescue Psych::Exception
        nil
      end

      def seconds(given)
        match = /\A(\d+)([smh]?)\z/.match(given.to_s)
        match && (match[1].to_i * UNITS.fetch(match[2]))
      end

      def raw = (@text && YAML.safe_load(@text, aliases: true)) || {}
      def values = DEFAULTS.merge(raw)
    end
  end
end
