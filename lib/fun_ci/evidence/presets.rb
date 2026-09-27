# frozen_string_literal: true

require "yaml"

module FunCi
  module Evidence
    # The presets in presets.yml: each a built-in (`use`) and its options.
    module Presets
      FILE = File.join(__dir__, "presets.yml")

      # markers: files any of which the worktree must have, each a path or
      # { path, contains }; signature: a pattern only the tool prints. Either
      # may be missing (why.md, "Choosing which run").
      Preset = Data.define(:name, :use, :options, :markers, :signature)
      OWN = %w[use markers signature].freeze

      def self.all
        @all ||= YAML.safe_load_file(FILE).map do |name, raw|
          Preset.new(name: name, use: raw.fetch("use"), options: raw.except(*OWN), markers: raw.fetch("markers", []),
                     signature: raw["signature"])
        end
      end

      def self.fetch(name) = all.find { |preset| preset.name == name } || raise(KeyError, "no preset '#{name}'")
      def self.find(use, name) = all.find { |preset| preset.use == use && preset.name == name }
    end
  end
end
