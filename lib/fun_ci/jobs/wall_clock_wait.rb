# frozen_string_literal: true

module FunCi
  module Jobs
    # Waits seconds by the wall clock, a minute at a time, for a job's turn
    # (Schedule), which can be hours away: sleep's own count stops while the
    # machine sleeps, and a laptop asleep for part of the wait would start the
    # job late. It sleeps no more minutes than the wait holds and one, so a
    # clock that never moves can't keep it waiting for ever.
    class WallClockWait
      MINUTE = 60

      def initialize(clock: -> { Time.now }, sleep: Kernel.method(:sleep))
        @clock = clock
        @sleep = sleep
      end

      def call(seconds)
        until_at = @clock.call + seconds
        ((seconds / MINUTE).ceil + 1).times do
          left = until_at - @clock.call
          break unless left.positive?

          @sleep.call([left, MINUTE].min)
        end
      end
    end
  end
end
