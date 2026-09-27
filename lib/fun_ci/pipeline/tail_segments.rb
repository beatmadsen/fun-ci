# frozen_string_literal: true

module FunCi
  module Pipeline
    # The last `size` bytes of a stream, kept in two IOs of `size` bytes that
    # take turns: when one fills, the other is emptied and written next.
    class TailSegments
      def initialize(open, size)
        @open = open
        @size = size
        @filled = 0
        @segments = nil
      end

      def <<(bytes)
        until bytes.empty?
          rotate if @filled == @size
          part = bytes.byteslice(0, @size - @filled)
          segments.last.write(part)
          @filled += part.bytesize
          bytes = bytes.byteslice(part.bytesize..)
        end
      end

      def read
        return +"".b unless @segments

        earlier(@size - @filled) + whole(segments.last)
      end

      def close = @segments&.each(&:close)

      private

      def segments = @segments ||= [@open.call("tail-0"), @open.call("tail-1")]

      def rotate
        @segments = segments.reverse
        segments.last.truncate(0)
        segments.last.rewind
        @filled = 0
      end

      def earlier(count)
        io = segments.first
        return +"".b if count.zero? || io.size < count

        io.seek(io.size - count)
        io.read(count)
      end

      def whole(io)
        io.rewind
        io.read
      end
    end
  end
end
