# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "test_report"
require_relative "output_window"
require_relative "../persistence/state_dir"

module FunCi
  module Pipeline
    # A stage's own directory, named for the process that made it, in the
    # state directory: it holds `reports`, the empty directory named to the
    # stage as FUN_CI_REPORT (acceptance-tests.md, AT-9.7), JUnit XML (*.xml)
    # and fun-ci's JSON (*.json), and the window its output is written to,
    # unmasked, until the stage is recorded (AT-10.6).
    class StageDir
      READERS = { ".xml" => TestReport.method(:junit), ".json" => TestReport.method(:json) }.freeze

      def self.default_root = File.join(Persistence::StateDir.path(ENV), "stages")

      # Removes the directories of processes that died before removing their own.
      def self.create(root = default_root)
        FileUtils.mkdir_p(root)
        Dir.children(root).reject { |name| alive?(name.to_i) }.each { |name| FileUtils.rm_rf(File.join(root, name)) }
        new(Dir.mktmpdir("#{Process.pid}-", root)).tap { |dir| Dir.mkdir(dir.reports_path) }
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

      def reports_path = File.join(@path, "reports")
      def env = { "FUN_CI_REPORT" => reports_path }
      def window(sizes = OutputWindow::REAL) = OutputWindow.in(@path, sizes)

      def failures
        Dir.children(reports_path).sort.flat_map { |name| read(name) || [] }
      end

      def remove = FileUtils.rm_rf(@path)

      private

      def read(name)
        reader = READERS[File.extname(name)]
        reader&.call(File.read(File.join(reports_path, name)))
      end
    end
  end
end
