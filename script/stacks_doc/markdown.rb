# frozen_string_literal: true

module StacksDoc
  # The bits of GitHub Markdown the page is made of.
  module Markdown
    def self.code(text) = "`#{text.gsub("|", "\\|")}`"
    def self.row(cells) = "| #{cells.join(" | ")} |"
    def self.table(header, rows) = [row(header), row(header.map { "---" }), *rows.map { |cells| row(cells) }].join("\n")
  end
end
