# frozen_string_literal: true

require "fun_ci/trunk/check"

# Builds checks against the trunk the way the pipeline records them.
module TrunkKit
  TRUNK_SHA = "9e1d004aaaabbbbccccddddeeeeffff000011112"
  MERGE = FunCi::Trunk::Merge

  def trunk_check(commit, merge, seen_at:, sha: TRUNK_SHA)
    FunCi::Trunk::Check.new(commit: commit, tip: trunk_tip(sha: sha, seen_at: seen_at), merge: merge)
  end

  def trunk_tip(seen_at:, sha: TRUNK_SHA, remote: "origin", branch: "main")
    FunCi::Trunk::Tip.new(remote: remote, branch: branch, sha: sha, seen_at: seen_at)
  end
end
