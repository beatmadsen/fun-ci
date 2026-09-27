# frozen_string_literal: true

require_relative "stamp"
require_relative "../pipeline/output_window"

module FunCi
  module Evidence
    # The files of the worktree a stage ran in, by path relative to it. A
    # file is read through a window of the output's sizes, so a log that
    # grew without end is read as its first and last parts.
    class Worktree
      CHUNK = 1_048_576

      def initialize(dir, sizes = Pipeline::OutputWindow::REAL)
        @dir = dir
        @sizes = sizes
      end

      def exist?(path) = File.file?(full(path))
      def glob(pattern) = Dir.glob(pattern, base: @dir).select { |path| exist?(path) }.sort

      def read(path, from: 0)
        window = Pipeline::OutputWindow.in_memory(@sizes)
        each_chunk(path, from) { |chunk| window << chunk }
        window.text
      end

      def lines_before(path, offset)
        count = 0
        each_chunk(path, 0, offset) { |chunk| count += chunk.count("\n") }
        count
      end

      def stamp(path)
        stat = File.stat(full(path))
        Stamp.new(size: stat.size, mtime: stat.mtime.to_r, inode: stat.ino)
      end

      private

      def full(path) = File.join(@dir, path)

      # Yields the file's bytes from `from`, `length` of them or to its end, a chunk at a time.
      def each_chunk(path, from, length = nil, &)
        File.open(full(path), "rb") do |file|
          file.seek(from)
          read_chunks(file, length, &)
        end
      end

      def read_chunks(file, left)
        loop do
          chunk = file.read(left ? [CHUNK, left].min : CHUNK)
          break if chunk.nil? || chunk.empty?

          yield chunk
          left -= chunk.bytesize if left
        end
      end
    end
  end
end
