# frozen_string_literal: true

module FunCi
  module Trunk
    # One check of a commit against one trunk SHA (docs/trunk-conflicts.md):
    # ahead and behind count the commits each has that the other lacks, and
    # outcome is "clean", "conflicts" (in `files`) or "unknown" (for `reason`).
    # seen_at is when fun-ci first saw that trunk SHA.
    Check = Data.define(:commit, :ref, :trunk_sha, :seen_at, :outcome, :ahead, :behind, :files, :reason)

    class Check
      def initialize(ahead: nil, behind: nil, files: [], reason: nil, **) = super
    end
  end
end
