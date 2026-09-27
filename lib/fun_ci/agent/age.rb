# frozen_string_literal: true

module FunCi
  module Agent
    # How long ago something happened, in the largest whole unit.
    module Age
      UNITS = [[86_400, "d"], [3600, "h"], [60, "m"]].freeze

      def self.words(seconds)
        size, unit = UNITS.find { |unit_seconds, _| seconds >= unit_seconds }
        size ? "#{(seconds / size).floor}#{unit} ago" : "just now"
      end
    end
  end
end
