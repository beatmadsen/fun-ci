# frozen_string_literal: true

module FunCi
  module Trunk
    # The trunk as fun-ci saw it: its ref, the SHA at its tip, and when fun-ci
    # first saw that SHA.
    Tip = Data.define(:ref, :sha, :seen_at)

    # What merging a commit with a trunk tip would do: ahead and behind count
    # the commits each has that the other lacks, and outcome is "clean",
    # "conflicts" (in `files`) or "unknown" (for `reason`).
    Merge = Data.define(:outcome, :ahead, :behind, :files, :reason)

    class Merge
      def self.clean(ahead:, behind:) = new(outcome: "clean", ahead: ahead, behind: behind, files: [], reason: nil)

      def self.conflicts(files, ahead:, behind:)
        new(outcome: "conflicts", ahead: ahead, behind: behind, files: files, reason: nil)
      end

      def self.unknown(reason) = new(outcome: "unknown", ahead: nil, behind: nil, files: [], reason: reason)
    end

    # One check of a commit against one trunk tip (docs/trunk-conflicts.md).
    Check = Data.define(:commit, :tip, :merge)
  end
end
