# frozen_string_literal: true

require_relative "catalog"
require_relative "patterns"

module FunCi
  module Evidence
    # What is wrong with the `evidence` key of .fun-ci/config, each as a line
    # `fun-ci check` prints.
    class SettingsCheck
      KNOWN = %w[budget detect skip mask masking stages].freeze
      STAGES = %w[all lint build fast slow].freeze

      # "2", 2, 2.5 or "2s" as seconds, or nil.
      def self.seconds(value)
        match = /\A(\d+(?:\.\d+)?)s?\z/.match(value.to_s)
        match && match[1].to_f.positive? ? match[1].to_f : nil
      end

      def initialize(raw, root)
        @raw = raw
        @root = root
      end

      def errors
        return [] if @raw.nil?
        return ["evidence must be a mapping, not #{@raw.inspect}"] unless @raw.is_a?(Hash)

        unknown + budget + stages
      end

      private

      def unknown = (@raw.keys - KNOWN).map { |key| "evidence has no setting '#{key}'" }

      def budget
        return [] if !@raw.key?("budget") || self.class.seconds(@raw["budget"])

        ["evidence.budget must be a number of seconds such as 2 or 2s, not #{@raw["budget"].inspect}"]
      end

      def stages
        lists = @raw.fetch("stages", {})
        return ["evidence.stages must be a mapping of stage to entries"] unless lists.is_a?(Hash)

        lists.flat_map { |stage, entries| stage_errors(stage, entries) }
      end

      def stage_errors(stage, entries)
        unless STAGES.include?(stage)
          return ["evidence.stages has no stage '#{stage}': use all, lint, build, fast or slow"]
        end

        Array(entries).filter_map { |entry| refusal(entry) }.map { |message| "evidence.stages.#{stage}: #{message}" }
      end

      def refusal(entry)
        Catalog.entry(entry)
        script_mistake(entry)
      rescue Catalog::Refused => e
        e.message
      end

      # A `run:` command's first word, when it is a path, must name a script that can be run.
      def script_mistake(entry)
        script = entry["run"].to_s.split.first.to_s
        return nil unless @root && script.include?("/")

        path = File.join(@root, script)
        return "run:#{entry["run"]}: #{script} doesn't exist" unless File.exist?(path)

        "run:#{entry["run"]}: #{script} isn't executable" unless File.executable?(path)
      end
    end
  end
end
