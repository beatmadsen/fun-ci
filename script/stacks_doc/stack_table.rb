# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require_relative "markdown"
require_relative "names"
require "fun_ci/setup/project_detector"
require "fun_ci/setup/stage_templates"

module StacksDoc
  # Each stack `fun-ci init` knows, in the order it tries them, with what
  # tells it and the command each stage script runs.
  module StackTable
    HEADER = ["Stack", "Detected by", "lint.sh", "build.sh", "fast.sh", "slow.sh"].freeze

    def self.markdown
      Markdown.table(HEADER, FunCi::Setup::ProjectDetector::STACKS.map { |id, markers| row(id, markers) })
    end

    def self.row(id, markers)
      detected = markers.map { |marker| Array(marker).map { |name| Markdown.code(name) }.join(" and ") }
      [Names.stack(id), detected.join(" or "), *FunCi::Setup::StageTemplates.scripts(id).values.map { command(_1) }]
    end

    def self.command(script) = Markdown.code(script.lines[1].chomp)
  end
end
