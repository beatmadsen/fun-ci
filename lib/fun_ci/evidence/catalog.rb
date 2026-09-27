# frozen_string_literal: true

require_relative "option_check"
require_relative "presets"
require_relative "extractors/grep"
require_relative "extractors/section"
require_relative "extractors/log_file"
require_relative "extractors/json_log"

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
                    "log-file" => Extractors::LogFile, "json-log" => Extractors::JsonLog }.freeze
      SHARED = %w[use on preset].freeze

      def self.entry(raw)
        raise Refused, "an entry must be a mapping with use: or run:, not #{raw.inspect}" unless raw.is_a?(Hash)

        built_in = BUILT_INS[raw["use"]] || raise(Refused, "unknown extractor '#{raw["use"]}'")
        options = checked_options(raw, built_in)
        Entry.new(name: [raw["use"], raw["preset"]].compact.join(":"), extractor: built_in.new(options), on: raw["on"])
      end

      def self.checked_options(raw, built_in)
        options = preset_options(raw).merge(raw.except(*SHARED))
        mistake = OptionCheck.mistake(raw["use"], built_in, options) || on_mistake(raw)
        raise Refused, mistake if mistake

        options
      end

      # The options of the preset an entry names, which its own replace.
      def self.preset_options(raw)
        return {} unless raw.key?("preset")

        preset = Presets.find(raw["use"], raw["preset"])
        preset ? preset.options : raise(Refused, "#{raw["use"]} has no preset '#{raw["preset"]}'")
      end

      def self.on_mistake(raw)
        return nil if [nil, "overrun"].include?(raw["on"])

        "#{raw["use"]}: 'on' must be overrun, not #{raw["on"].inspect}"
      end
      private_class_method :checked_options, :preset_options, :on_mistake
    end
  end
end
