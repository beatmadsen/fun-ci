# frozen_string_literal: true

require "yaml"

module FunCi
  module Evidence
    # The presets in presets/, one YAML file each (see its README): each a
    # built-in (`use`) and its options.
    module Presets
      DIR = File.join(__dir__, "presets")

      # markers: files any of which the worktree must have, each a path or
      # { path, contains }; signature: a pattern only the tool prints. Either
      # may be missing (architecture.md, "Evidence of a failed stage").
      Preset = Data.define(:name, :use, :options, :markers, :signature)
      OWN = %w[use markers signature].freeze

      def self.all
        @all ||= Dir.glob("*.yml", base: DIR).sort.map do |file|
          raw = YAML.safe_load_file(File.join(DIR, file))
          Preset.new(name: File.basename(file, ".yml"), use: raw.fetch("use"), options: raw.except(*OWN),
                     markers: raw.fetch("markers", []), signature: raw["signature"])
        end
      end

      def self.fetch(name) = all.find { |preset| preset.name == name } || raise(KeyError, "no preset '#{name}'")
      def self.find(use, name) = all.find { |preset| preset.use == use && preset.name == name }
    end
  end
end
