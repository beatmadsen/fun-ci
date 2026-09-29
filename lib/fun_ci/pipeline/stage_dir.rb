# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "output_window"
require_relative "../persistence/state_dir"

module FunCi
  module Pipeline
    # A stage's own directory, named for the process that made it, in the
    # state directory: it holds the window its output is written to, unmasked,
    # until the stage is recorded (AT-10.6), and what a project's extractor
    # reads and writes.
    class StageDir
      def self.default_root = File.join(Persistence::StateDir.path(ENV), "stages")

      # Removes the directories of processes that died before removing their own.
      def self.create(root = default_root)
        FileUtils.mkdir_p(root)
        Dir.children(root).reject { |name| alive?(name.to_i) }.each { |name| FileUtils.rm_rf(File.join(root, name)) }
        new(Dir.mktmpdir("#{Process.pid}-", root))
      end

      def self.alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
      private_class_method :alive?

      def initialize(path)
        @path = path
      end

      # The output as the window kept it, written for a project's extractor to read.
      def output_file(text)
        File.join(@path, "output.log").tap { |file| File.binwrite(file, text) }
      end

      # Where a project's extractor writes what it needs to (its stdin and stderr).
      def scratch = @path
      def window(sizes = OutputWindow::REAL) = OutputWindow.in(@path, sizes)

      def remove = FileUtils.rm_rf(@path)
    end
  end
end
