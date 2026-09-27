# frozen_string_literal: true

require_relative "presets"
require_relative "line_scan"
require_relative "patterns"

module FunCi
  module Evidence
    # Which presets run when a stage fails (why.md, "Choosing which run").
    # When it starts, the candidates: presets any of whose marker files the
    # worktree has (a marker may also name a text the file must hold), and
    # presets without markers. When it fails, of the candidates with an
    # output signature, those whose signature matched a line; the output is
    # read once, against the signatures joined.
    module Detection
      # because: why it was chosen, such as "file Gemfile", or nil.
      Found = Data.define(:preset, :because)

      def self.candidates(worktree, presets)
        presets.filter_map do |preset|
          next Found.new(preset: preset, because: nil) if preset.markers.empty?

          marker = preset.markers.find { |candidate| present?(worktree, candidate) }
          marker && Found.new(preset: preset, because: "file #{path(marker)}")
        end
      end

      def self.chosen(lines, candidates, deadline)
        seen = SignatureScan.new(candidates.map(&:preset)).seen(lines, deadline)
        candidates.filter_map { |found| chose(found, seen) }
      end

      def self.chose(found, seen)
        return found unless found.preset.signature

        matched = seen[found.preset.name]
        matched && found.with(because: [found.because, "output matched #{matched.inspect}"].compact.join(", "))
      end

      def self.present?(worktree, marker)
        return worktree.exist?(marker) if marker.is_a?(String)

        worktree.exist?(marker["path"]) && worktree.read(marker["path"]).include?(marker["contains"])
      end

      def self.path(marker) = marker.is_a?(String) ? marker : marker["path"]
      private_class_method :chose, :present?, :path
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
