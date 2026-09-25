# frozen_string_literal: true

require_relative "../../lib/fun_ci/tui/animation_library"

module FunCi
  module Contract
    # The 1.x animation library with its random choices pinned by name, so a
    # scenario draws the same frames on every capture.
    class PinnedAnimations
      LIBRARY = Tui::AnimationLibrary
      BY_NAME = (LIBRARY::FAILURE + LIBRARY::SUCCESS).to_h do |data|
        [Animations.constants.find { |c| Animations.const_get(c)::DATA.equal?(data) }.to_s.downcase, data]
      end.freeze

      attr_reader :random_failure, :random_success

      def initialize
        @random_failure = LIBRARY::FAILURE.first
        @random_success = LIBRARY::SUCCESS.first
      end

      def pin(name)
        data = BY_NAME.fetch(name) { raise ArgumentError, "unknown animation #{name.inspect}" }
        LIBRARY::FAILURE.include?(data) ? @random_failure = data : @random_success = data
      end

      def idle = LIBRARY.idle
      def running = LIBRARY.running
    end
  end
end
