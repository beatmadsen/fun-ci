# frozen_string_literal: true

require_relative "option_check"
require_relative "presets"
require_relative "extractors/grep"
require_relative "extractors/section"
require_relative "extractors/log_file"
require_relative "extractors/json_log"
require_relative "extractors/junit_files"
require_relative "extractors/command"
require_relative "extractors/process_tree"

module FunCi
  module Evidence
    # The built-in extractors by name, and how an entry of .fun-ci/config
    # becomes one to run (why.md, "Configuration"). An entry that can't is
    # Refused, with what is wrong with it.
    module Catalog
      class Refused < StandardError; end

      # name: what the evidence credits (`grep`, `section:rspec`); on: nil, or "overrun".
      Entry = Data.define(:name, :extractor, :on)

      BUILT_INS = { "grep" => Extractors::Grep, "section" => Extractors::Section,
                    "log-file" => Extractors::LogFile, "json-log" => Extractors::JsonLog,
                    "junit-files" => Extractors::JunitFiles, "process-tree" => Extractors::ProcessTree }.freeze
      SHARED = %w[use on preset].freeze

      def self.entry(raw)
        raise Refused, "an entry must be a mapping with use: or run:, not #{raw.inspect}" unless raw.is_a?(Hash)

        raw.key?("run") ? command(raw) : built_in(raw)
      end

      def self.built_in(raw)
        built_in = BUILT_INS[raw["use"]] || raise(Refused, "unknown extractor '#{raw["use"]}'")
        Entry.new(name: [raw["use"], raw["preset"]].compact.join(":"),
                  extractor: built_in.new(checked_options(raw, built_in)), on: raw["on"])
      end

      def self.checked_options(raw, built_in)
        options = preset_options(raw).merge(raw.except(*SHARED))
        mistake = OptionCheck.mistake(raw["use"], built_in, options) || on_mistake(raw)
        raise Refused, mistake if mistake

        options
      end

      # A project's own extractor. Whatever the entry says besides run:,
      # format:, watch: and on: is passed on to it.
      def self.command(raw)
        mistake = command_mistake(raw) || on_mistake(raw)
        raise Refused, mistake if mistake

        Entry.new(name: "run:#{raw["run"]}", extractor: Extractors::Command.new(raw.except("on")), on: raw["on"])
      end

      def self.command_mistake(raw)
        unless raw["run"].is_a?(String) && !raw["run"].empty?
          return "run: must name a command, not #{raw["run"].inspect}"
        end
        return nil if [nil, "text", "json"].include?(raw["format"])

        "run:#{raw["run"]}: 'format' must be text or json, not #{raw["format"].inspect}"
      end

      # The options of the preset an entry names, which its own replace.
      def self.preset_options(raw)
        return {} unless raw.key?("preset")

        preset = Presets.find(raw["use"], raw["preset"])
        preset ? preset.options : raise(Refused, "#{raw["use"]} has no preset '#{raw["preset"]}'")
      end

      def self.on_mistake(raw)
        return nil if [nil, "overrun"].include?(raw["on"])

        "#{raw["use"] || "run:#{raw["run"]}"}: 'on' must be overrun, not #{raw["on"].inspect}"
      end
      private_class_method :built_in, :command, :command_mistake, :checked_options, :preset_options, :on_mistake
    end
  end
end
