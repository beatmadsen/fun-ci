# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "frame_recorder"

module FunCi
  module Contract
    # Scenarios in <root>/scenarios/<name>.jsonl, and the Ruby renderer's
    # frames for them in <root>/golden/<name>/NNNN.bytes.
    class GoldenCorpus
      def initialize(root:)
        @root = root
      end

      def scenario_names
        Dir.glob(File.join(@root, "scenarios", "*.jsonl")).map { |path| File.basename(path, ".jsonl") }.sort
      end

      def messages(name)
        File.readlines(File.join(@root, "scenarios", "#{name}.jsonl"), chomp: true).map { |line| JSON.parse(line) }
      end

      def capture(name)
        FrameRecorder.build.replay(messages(name))
      end

      def golden(name)
        frame_paths(name).map { |path| File.binread(path) }
      end

      def write(name, frames)
        FileUtils.rm_f(frame_paths(name))
        FileUtils.mkdir_p(golden_dir(name))
        frames.each.with_index(1) { |frame, i| File.binwrite(frame_path(name, i), frame) }
      end

      private

      def frame_paths(name)
        Dir.glob(File.join(golden_dir(name), "*.bytes"))
      end

      def frame_path(name, number)
        File.join(golden_dir(name), format("%04d.bytes", number))
      end

      def golden_dir(name)
        File.join(@root, "golden", name)
      end
    end
  end
end
