# frozen_string_literal: true

require_relative "../animations/explosion"
require_relative "../animations/success"
require_relative "../animations/celebrate"
require_relative "../animations/flash"
require_relative "../animations/leprechauns"
require_relative "../animations/yay"
require_relative "../animations/idle"
require_relative "../animations/running"

module FunCi
  module Tui
    module AnimationLibrary
      FAILURE = [Animations::Explosion::DATA].freeze

      SUCCESS = [
        Animations::Success::DATA,
        Animations::Celebrate::DATA,
        Animations::Flash::DATA,
        Animations::Leprechauns::DATA,
        Animations::Yay::DATA
      ].freeze

      IDLE = Animations::Idle::DATA

      RUNNING = Animations::Running::DATA

      def self.random_failure
        FAILURE.sample
      end

      def self.random_success
        SUCCESS.sample
      end

      def self.idle
        IDLE
      end

      def self.running
        RUNNING
      end
    end
  end
end
