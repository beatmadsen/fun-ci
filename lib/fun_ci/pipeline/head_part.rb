# frozen_string_literal: true

module FunCi
  module Pipeline
    # The first `size` bytes of a stream, kept in an IO opened when first written.
    class HeadPart
      def initialize(open, size)
        @open = open
        @size = size
        @closed = false
      end

      # Writes what fits, and answers the rest.
      def take(bytes)
        room = [@size - written, 0].max
        io.write(bytes.byteslice(0, room)) if room.positive? && !bytes.empty?
        bytes.byteslice(room..) || "".b
      end

      def read
        return +"".b unless @io

        @io.rewind
        @io.read
      end

      def close
        @io&.close
        @closed = true
      end

      def closed? = @closed

      private

      def written = @io ? @io.size : 0
      def io = @io ||= @open.call("head")
    end
  end
end
