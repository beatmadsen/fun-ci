# frozen_string_literal: true

require_relative "check"

module FunCi
  module Trunk
    # What merging a commit with a trunk tip would do (architecture.md, Checking against the trunk,
    # How the check works), from what git answers: the commits each side has
    # that the other lacks, then, when both have some, a merge in memory.
    class MergeCheck
      # What a git command answered: its exit status and what it printed.
      Answer = Data.define(:status, :out, :err)
      # A merge stopped at its budget, with its process group.
      OVER_BUDGET = Answer.new(status: :over_budget, out: "", err: "")
      STOPPED = "the merge ran over its #{CHECK_BUDGET} s budget; " \
                "set trunk: none in .fun-ci/config to stop checking".freeze

      def initialize(git)
        @git = git
      end

      # name: how the trunk is called in a reason, "origin/main".
      def merge(commit, trunk, name)
        counted = @git.counts(commit, trunk)
        return Merge.unknown("git rev-list: #{first_line(counted)}") unless counted.status.zero?

        ahead, behind = counted.out.split.map(&:to_i)
        return Merge.clean(ahead: ahead, behind: behind) if ahead.zero? || behind.zero?

        merged(@git.merge_tree(commit, trunk), name, ahead: ahead, behind: behind)
      end

      private

      def merged(answer, name, **counts)
        return Merge.unknown(STOPPED) if answer.equal?(OVER_BUDGET)
        return Merge.clean(**counts) if answer.status.zero?
        return Merge.conflicts(MergeOutput.parse(answer.out).paths, **counts) if answer.status == 1

        Merge.unknown(reason(answer, name))
      end

      def reason(answer, name)
        return "#{name} shares no history with this commit; set trunk: in .fun-ci/config" if unrelated?(answer)
        return "needs git 2.38 or later; this is #{@git.version}" if answer.status == 129

        "git merge-tree: #{first_line(answer)}"
      end

      def unrelated?(answer) = answer.err.include?("unrelated histories")
      def first_line(answer) = answer.err.lines.first.to_s.chomp
    end
  end
end
