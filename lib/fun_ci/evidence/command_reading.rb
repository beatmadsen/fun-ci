# frozen_string_literal: true

module FunCi
  module Evidence
    # Reads a command's stdout in a thread, up to `limit` bytes; past that it
    # calls `stop`, which kills the command.
    class CommandReading
      def self.start(reader, limit, stop) = new(reader, limit, stop).tap(&:begin)

      def initialize(reader, limit, stop)
        @reader = reader
        @limit = limit
        @stop = stop
      end

      def begin = @thread = Thread.new { read(+"".b) }

      # All that was read, once reading ends or the drain is over.
      def finish(drain)
        @thread.join(drain)
        @reader.close
        @thread.value
      end

      private

      def read(buffer)
        loop do
          buffer << @reader.readpartial(65_536)
          break @stop.call if buffer.bytesize > @limit
        end
        buffer
      rescue IOError
        buffer
      end
    end
  end
end
