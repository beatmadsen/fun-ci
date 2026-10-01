# frozen_string_literal: true

require "yaml"
require_relative "catalog"
require_relative "patterns"
require_relative "settings_check"
require_relative "../jobs/job"

module FunCi
  module Evidence
    # The `evidence` key of .fun-ci/config (architecture.md, "Evidence of a failed stage"): the
    # settings, each with its default, and each stage's entries, those for
    # `all` first. A setting that is wrong takes its default; #errors says
    # what is wrong, for `fun-ci check`.
    class Settings
      DEFAULTS = { "budget" => 2, "detect" => true, "skip" => [], "mask" => [], "masking" => true,
                   "stages" => {}, "jobs" => {} }.freeze

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

      # The raw entries for `stage`: those for every stage, then its own; for
      # a job (`jobs/<name>`), those under `jobs:`.
      def entries(stage)
        job = Jobs::Job.named_by(stage)
        stage_list("all") + (job ? list("jobs", job) : stage_list(stage))
      end

      # The globs whose files are stamped when the stage starts, so what it
      # wrote to them can be told from what was there before.
      def watched(stage)
        entries(stage).grep(Hash).flat_map { |raw| Array(raw["path"]) + Array(raw["paths"]) + Array(raw["watch"]) }
                      .grep(String).uniq
      end

      # root: the project, whose `run:` scripts are checked when it is given.
      def errors(root: nil) = SettingsCheck.new(@raw, root).errors

      private

      def values = @raw.is_a?(Hash) ? DEFAULTS.merge(@raw) : DEFAULTS
      def value(key) = values[key]

      def stage_list(stage) = list("stages", stage)

      def list(setting, name)
        lists = value(setting)
        found = lists[name] if lists.is_a?(Hash)
        found.is_a?(Array) ? found : []
      end
    end
  end
end
