# frozen_string_literal: true

require_relative "option_check"
require_relative "extractors/grep"

module FunCi
  module Evidence
    # The built-in extractors by name, and how an entry of .fun-ci/config
    # becomes one to run (why.md, "Configuration"). An entry that can't is
    # Refused, with what is wrong with it.
    module Catalog
      class Refused < StandardError; end

      # name: what the evidence credits (`grep`, `section:rspec`); on: nil, or "overrun".
      Entry = Data.define(:name, :extractor, :on)

      BUILT_INS = { "grep" => Extractors::Grep }.freeze
      SHARED = %w[use on].freeze

      def self.entry(raw)
        raise Refused, "an entry must be a mapping with use: or run:, not #{raw.inspect}" unless raw.is_a?(Hash)

        built_in = BUILT_INS[raw["use"]] || raise(Refused, "unknown extractor '#{raw["use"]}'")
        options = raw.except(*SHARED)
        mistake = OptionCheck.mistake(raw["use"], built_in, options) || on_mistake(raw)
        raise Refused, mistake if mistake

        Entry.new(name: raw["use"], extractor: built_in.new(options), on: raw["on"])
      end

      def self.on_mistake(raw)
        return nil if [nil, "overrun"].include?(raw["on"])

        "#{raw["use"]}: 'on' must be overrun, not #{raw["on"].inspect}"
      end
      private_class_method :on_mistake
    end
  end
end
