# frozen_string_literal: true

require "io/nonblock"

module FunCi
  module Pipeline
    # A pipe a child process waits on until the caller opens it. Ruby makes
    # pipes non-blocking, and a child shares that setting with the parent, so
    # the child's end is made blocking: otherwise a child reading before the
    # caller has opened the gate fails instead of waiting.
    class Gate
      attr_reader :child_end

      def self.create
        child_end, opener = IO.pipe
        child_end.nonblock = false
        new(child_end, opener)
      end

      def initialize(child_end, opener)
        @child_end = child_end
        @opener = opener
      end

      # Lets the child through. A child that has gone already needs nothing.
      def open
        @opener.puts
      rescue Errno::EPIPE
        nil
      ensure
        @opener.close
      end
    end
  end
end
