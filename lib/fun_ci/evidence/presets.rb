# frozen_string_literal: true

require "yaml"

module FunCi
  module Evidence
    # The presets in presets.yml: each a built-in (`use`) and its options.
    module Presets
      FILE = File.join(__dir__, "presets.yml")

      Preset = Data.define(:name, :use, :options)

      def self.all
        @all ||= YAML.safe_load_file(FILE).map do |name, raw|
          Preset.new(name: name, use: raw.fetch("use"), options: raw.except("use"))
        end
      end

      def self.fetch(name) = all.find { |preset| preset.name == name } || raise(KeyError, "no preset '#{name}'")
      def self.find(use, name) = all.find { |preset| preset.use == use && preset.name == name }
    end
  end
end
