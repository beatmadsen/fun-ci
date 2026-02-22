# frozen_string_literal: true

module FunCi
  module Tui
    class Spinner
      BRAILLE_FRAMES = %W[\u2800 \u2801 \u2803 \u2807 \u280F \u281F \u283F \u287F].freeze

      attr_reader :frames

      def initialize
        @frames = BRAILLE_FRAMES
        @index = 0
      end

      def current_frame
        @frames[@index]
      end

      def advance!
        @index = (@index + 1) % @frames.length
      end
    end
  end
end
