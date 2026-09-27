# frozen_string_literal: true

require "yaml"
require_relative "catalog"
require_relative "patterns"
require_relative "settings_check"

module FunCi
  module Evidence
    # The `evidence` key of .fun-ci/config (why.md, "Configuration"): the
    # settings, each with its default, and each stage's entries, those for
    # `all` first. A setting that is wrong takes its default; #errors says
    # what is wrong, for `fun-ci check`.
    class Settings
      DEFAULTS = { "budget" => 2, "detect" => true, "skip" => [], "mask" => [], "masking" => true,
                   "stages" => {} }.freeze

      # The settings in the config file at `path`, or the defaults without one.
      def self.load(path)
        new(File.exist?(path) ? (YAML.safe_load_file(path) || {})["evidence"] : nil)
      rescue Psych::Exception, NoMethodError, TypeError
        new(nil)
      end

      def initialize(raw)
        @raw = raw
      end

      def budget = SettingsCheck.seconds(value("budget")) || DEFAULTS.fetch("budget").to_f
      def detect? = value("detect") != false
      def masking? = value("masking") != false
      def skip = Array(value("skip"))

      def mask_patterns
        Array(value("mask")).select { |source| source.is_a?(String) && !Patterns.mistake(source) }
                            .then { |sources| Patterns.compile(sources) }
      end

      # The raw entries for `stage`: those for every stage, then its own.
      def entries(stage) = stage_list("all") + stage_list(stage)

      # The globs whose files are stamped when the stage starts, so what it
      # wrote to them can be told from what was there before.
      def watched(stage)
        entries(stage).grep(Hash).flat_map { |raw| Array(raw["path"]) + Array(raw["paths"]) }
                      .grep(String).uniq
      end

      def errors = SettingsCheck.new(@raw).errors

      private

      def values = @raw.is_a?(Hash) ? DEFAULTS.merge(@raw) : DEFAULTS
      def value(key) = values[key]

      def stage_list(stage)
        stages = value("stages")
        list = stages.is_a?(Hash) ? stages[stage] : nil
        list.is_a?(Array) ? list : []
      end
    end
  end
end
