# frozen_string_literal: true

module FunCi
  module Agent
    # The real time, for commands that wait.
    class SystemClock
      def now = Time.now
      def pause(seconds) = sleep(seconds)
    end
  end
end
