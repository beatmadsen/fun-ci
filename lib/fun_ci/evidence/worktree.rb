# frozen_string_literal: true

module FunCi
  module Evidence
    # The files of the worktree a stage ran in, by path relative to it.
    class Worktree
      def initialize(dir)
        @dir = dir
      end

      def read(path) = File.binread(full(path))
      def exist?(path) = File.file?(full(path))
      def glob(pattern) = Dir.glob(pattern, base: @dir).select { |path| exist?(path) }.sort

      private

      def full(path) = File.join(@dir, path)
    end
  end
end
