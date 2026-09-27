# frozen_string_literal: true

module FunCi
  module Evidence
    # When the evidence budget runs out. `clock` answers the time in seconds.
    Deadline = Data.define(:clock, :at)

    class Deadline
      def self.after(clock, seconds) = new(clock: clock, at: clock.call + seconds)

      def passed? = clock.call >= at
      def left = [at - clock.call, 0].max
    end
  end
end
