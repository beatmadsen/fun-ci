# frozen_string_literal: true

require_relative "presets"
require_relative "line_scan"
require_relative "patterns"
require_relative "source"

module FunCi
  module Evidence
    # Which presets run when a stage fails (architecture.md, "Evidence of a failed stage").
    # When it starts, the candidates: presets any of whose marker files the
    # worktree has (a marker may also name a text the file must hold), and
    # presets without markers. When it fails, of the candidates with an
    # output signature, those whose signature matched a line of the output's
    # last megabyte, where tools print their summaries: each signature costs
    # a read, and over the whole window with every preset a candidate that
    # was most of the budget (script/bench_detection.rb). The part is read
    # once, against the signatures joined.
    module Detection
      # because: why it was chosen, such as "file Gemfile", or nil.
      Found = Data.define(:preset, :because)
      SCAN_BYTES = 1_048_576

      def self.candidates(worktree, presets)
        presets.filter_map do |preset|
          next Found.new(preset: preset, because: nil) if preset.markers.empty?

          file = preset.markers.lazy.filter_map { |marker| marked(worktree, marker) }.first
          file && Found.new(preset: preset, because: "file #{file}")
        end
      end

      def self.chosen(output, candidates, deadline, scan_bytes: SCAN_BYTES)
        last_part = output.byteslice([output.bytesize - scan_bytes, 0].max..)
        seen = SignatureScan.new(candidates.map(&:preset)).seen(Source.of("output", last_part).lines, deadline)
        candidates.filter_map { |found| chose(found, seen) }
      end

      def self.chose(found, seen)
        return found unless found.preset.signature

        matched = seen[found.preset.name]
        matched && found.with(because: [found.because, "output matched #{matched.inspect}"].compact.join(", "))
      end

      # The file that bears the marker out, or nil. A marker is a path or a
      # glob, or { path, contains } for a file that must hold a text.
      def self.marked(worktree, marker)
        return worktree.glob(marker).first if marker.is_a?(String)

        path = marker["path"]
        path if worktree.exist?(path) && worktree.read(path).include?(marker["contains"])
      end
      private_class_method :chose, :marked
    end

    # Reads lines once against a set of presets' signatures joined into one
    # pattern; a line the joined pattern matches is tried against each
    # signature, since a joined pattern reports one of those that match.
    class SignatureScan
      def initialize(presets)
        @signatures = presets.select(&:signature).to_h { |preset| [preset.name, Regexp.new(preset.signature)] }
        @joined = Patterns.compile(@signatures.values.map { |pattern| "(?:#{pattern.source})" }.join("|")).first
      end

      # The first text each signature matched, by preset name.
      def seen(lines, deadline)
        seen = {}
        return seen if @signatures.empty?

        LineScan.cut_short?(lines, deadline) { |line, _| note(seen, line) if @joined.match?(line) }
        seen
      end

      private

      def note(seen, line)
        @signatures.each { |name, pattern| seen[name] ||= pattern.match(line)&.[](0) }
      end
    end
  end
end
