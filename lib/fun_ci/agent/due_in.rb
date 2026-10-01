# frozen_string_literal: true

module FunCi
  module Agent
    # How long until something, rounded up, since it is still to come, in the
    # largest unit it reaches once rounded: `45m`, `22h`, `7d`; as the console says it.
    module DueIn
      def self.words(seconds)
        minutes = up(seconds, 60).clamp(1..)
        hours = up(seconds, 3600)
        return "#{minutes}m" if minutes < 60
        return "#{hours}h" if hours < 24

        "#{up(seconds, 86_400)}d"
      end

      def self.up(seconds, unit) = (seconds.to_r / unit).ceil
      private_class_method :up
    end
  end
end
