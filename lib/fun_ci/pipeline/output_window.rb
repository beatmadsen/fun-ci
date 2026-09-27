# frozen_string_literal: true

require "stringio"
require_relative "head_part"
require_relative "tail_segments"

module FunCi
  module Pipeline
    # What a stage printed, kept as its first `head` bytes and its last
    # `tail` bytes, written as it comes so no more than a chunk is held in
    # memory. Both cuts fall on line ends, unless a line is longer than the
    # part it is in, and a marker line says how many bytes were dropped.
    class OutputWindow
      Sizes = Data.define(:head, :tail)
      REAL = Sizes.new(head: 1_048_576, tail: 7_340_032)

      def self.in_memory(sizes = REAL) = new(->(_name) { StringIO.new(+"") }, sizes)

      def self.in(dir, sizes = REAL)
        new(->(name) { File.open(File.join(dir, name), "w+b") }, sizes)
      end

      # `open` answers a new, empty read-write IO for a name.
      def initialize(open, sizes)
        @sizes = sizes
        @written = 0
        @head = HeadPart.new(open, sizes.head)
        @tail = TailSegments.new(open, sizes.tail + 1)
      end

      def <<(chunk)
        bytes = chunk.b
        rest = @head.take(bytes)
        @tail << rest unless rest.empty?
        @written += bytes.bytesize
        self
      end

      def text
        head = @head.read
        return head + @tail.read if @written <= @sizes.head + @sizes.tail

        cut(head, @tail.read)
      end

      def close
        @head.close
        @tail.close
      end

      def closed? = @head.closed?

      private

      def cut(head, tail)
        kept_head = head.rindex("\n") ? head[0..head.rindex("\n")] : head
        kept_tail = line_start(tail)
        dropped = @written - kept_head.bytesize - kept_tail.bytesize
        "#{kept_head}[fun-ci: #{dropped} bytes dropped here]\n".b + kept_tail
      end

      # The tail holds one byte more than it keeps, to tell whether it starts on a line start.
      def line_start(tail)
        return tail.byteslice(1..) if tail.start_with?("\n") || !tail.include?("\n")

        tail.byteslice((tail.index("\n") + 1)..)
      end
    end
  end
end
