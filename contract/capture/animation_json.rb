# frozen_string_literal: true

require "json"
require_relative "styled_line"

module FunCi
  module Contract
    # A 1.x animation module's DATA as renderer/animations/<name>.json: each
    # frame's lines as plain text plus a style mask of the same length, whose
    # characters are keys into `styles` (a space is the terminal default).
    class AnimationJson
      LOOPING = %w[idle running].freeze
      KEYS = [*"a".."z", *"A".."Z"].freeze

      attr_reader :name

      def self.all
        Dir[File.expand_path("../../lib/fun_ci/animations/*.rb", __dir__)].each { |path| require path }
        Animations.constants.sort.map { |c| new(c.to_s.downcase, Animations.const_get(c)::DATA) }
      end

      def initialize(name, data)
        @name = name
        @data = data
      end

      def to_h
        { "name" => name, "frame_ms" => 1000 / @data[:fps], "loop" => LOOPING.include?(name),
          "anchor" => "header", "styles" => styles, "frames" => frames }
      end

      def json = "#{JSON.pretty_generate(to_h)}\n"

      private

      def frames
        parsed.map { |lines| { "text" => lines.map(&:text), "style" => lines.map { |line| line.mask(keys) } } }
      end

      def styles = keys.to_h { |style, key| [key, style.to_json_h] }

      def keys
        @keys ||= parsed.flatten.flat_map(&:cells).map(&:last).uniq.reject(&:default?).zip(KEYS).to_h
      end

      def parsed
        @parsed ||= @data[:frames].map { |frame| frame.map { |line| ending_in_default(StyledLine.parse(line)) } }
      end

      def ending_in_default(line)
        raise ArgumentError, "#{name}: #{line.text.inspect} leaves a style in force" unless line.finish.default?

        line
      end
    end
  end
end
