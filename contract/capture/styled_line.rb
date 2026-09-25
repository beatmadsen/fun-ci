# frozen_string_literal: true

require_relative "sgr_style"

module FunCi
  module Contract
    # One line of ANSI text as the characters a terminal would show, each with
    # the SGR style it is drawn in, plus the style left in force at its end.
    class StyledLine
      ESCAPE = /(\e\[[0-9;]*m)/

      attr_reader :cells, :finish

      def self.parse(line, start = SgrStyle.default)
        parts = line.split(ESCAPE)
        styles = parts.each_with_object([start]) { |part, acc| acc << style_after(acc.last, part) }
        cells = drawn(parts, styles)
        raise ArgumentError, "unsupported escape in #{line.inspect}" if cells.any? { |char, _| char == "\e" }

        new(cells, styles.last)
      end

      def self.drawn(parts, styles)
        parts.zip(styles).reject { |part, _| escape?(part) }
             .flat_map { |text, style| text.chars.map { |char| [char, style] } }
      end

      def self.escape?(part) = part.match?(ESCAPE)

      def self.style_after(style, part) = escape?(part) ? style.apply(part[2..-2]) : style

      def initialize(cells, finish)
        @cells = cells
        @finish = finish
      end

      def text = cells.map(&:first).join

      def mask(keys) = cells.map { |_, style| keys.fetch(style, " ") }.join
    end
  end
end
