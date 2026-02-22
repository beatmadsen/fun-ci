# frozen_string_literal: true

require_relative "ansi"

module FunCi
  module Tui
    class LoopingAnimationPlayer
      def initialize(data)
        @data = data
        @frame = 0
      end

      def advance!
        @frame += 1
      end

      def frame
        @frame % total_frames
      end

      def finished?
        false
      end

      def total_frames
        @data[:frames].length
      end

      def current_lines(width)
        frame_lines = @data[:frames][frame]
        return [] unless frame_lines

        frame_lines.map { |line| center_line(line, width) }
      end

      private

      def center_line(line, width)
        visible_len = Ansi.strip(line).length
        pad = [(width - visible_len) / 2, 0].max
        "#{" " * pad}#{line}\e[K"
      end
    end
  end
end
