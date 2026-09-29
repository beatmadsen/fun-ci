# frozen_string_literal: true

module FunCi
  module Trunk
    # Seconds a run's fetch of the trunk may take, and then its merge.
    FETCH_DEADLINE = 20
    CHECK_BUDGET = 5

    # The trunk as fun-ci saw it: its branch, on a remote or (remote nil)
    # local, the SHA at its tip, and when fun-ci first saw that SHA.
    Tip = Data.define(:remote, :branch, :sha, :seen_at)

    class Tip
      def ref = remote ? "#{remote}/#{branch}" : branch
    end

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

    # The last fetch of a project's trunk fun-ci tried: when one last
    # succeeded (nil if none has), and why the last one failed, if it did.
    LastFetch = Data.define(:fetched_at, :error)

    # A conflict with the trunk explained: git's messages about the merge, and
    # each conflicted file as the merge leaves it, by path.
    Explained = Data.define(:messages, :files)

    # What merge-tree prints: the merged tree's SHA, the conflicted paths, and
    # after a blank line git's messages.
    MergeOutput = Data.define(:tree, :paths, :messages)

    class MergeOutput
      def self.parse(out)
        lines = out.lines(chomp: true)
        paths = lines.drop(1).take_while { |line| !line.empty? }
        new(tree: lines.first, paths: paths, messages: lines.drop(paths.size + 2).reject(&:empty?))
      end
    end

    # One check of a commit against one trunk tip (architecture.md, Checking against the trunk);
    # the tip is nil when there was none to check against.
    Check = Data.define(:commit, :tip, :merge)
  end
end
