# frozen_string_literal: true

module FunCi
  module Agent
    # Polls until the answer is decided, or the deadline (a Time; nil for none) has passed
    # (acceptance-tests.md, AT-9.9, AT-9.10). An answer is decided once its
    # verdict is anything but undecided; nil (no run yet) is undecided.
    class Waiting
      POLL_SECONDS = 1

      def initialize(clock, deadline:, &poll)
        @clock = clock
        @deadline = deadline
        @poll = poll
      end

      def until_decided
        loop do
          answer = @poll.call
          return answer if decided?(answer) || out_of_time?

          @clock.pause(POLL_SECONDS)
        end
      end

      private

      def decided?(answer) = answer && answer.verdict != :undecided
      def out_of_time? = @deadline && @clock.now >= @deadline
    end
  end
end
