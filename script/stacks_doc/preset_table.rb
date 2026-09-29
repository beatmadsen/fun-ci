# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require_relative "markdown"
require_relative "names"
require_relative "../../test/support/preset_stacks"
require "fun_ci/evidence/presets"

module StacksDoc
  # Each preset: what it picks out, the stack it reads, and the files that
  # make it a candidate.
  module PresetTable
    HEADER = ["Preset", "Picks out", "Stack", "Runs in a project with any of"].freeze
    UNTITLED = { "json-log" => "Log records at warn or above" }.freeze

    def self.markdown = Markdown.table(HEADER, FunCi::Evidence::Presets.all.map { |preset| row(preset) })

    def self.row(preset)
      [Markdown.code(preset.name), preset.options.fetch("title") { UNTITLED.fetch(preset.use) },
       stack(preset.name), markers(preset.markers)]
    end

    def self.stack(name)
      placed = PresetStacks::STACKS[name]
      placed ? Names.family(placed.stack) : "Any"
    end

    def self.markers(markers)
      return "Any project" if markers.empty?

      markers.map { |marker| marker.is_a?(Hash) ? containing(marker) : Markdown.code(marker) }.join(", ")
    end

    def self.containing(marker)
      "#{Markdown.code(marker.fetch("path"))} holding #{Markdown.code(marker.fetch("contains"))}"
    end
  end
end
