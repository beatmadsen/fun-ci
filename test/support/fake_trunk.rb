# frozen_string_literal: true

require_relative "trunk_kit"
require "fun_ci/trunk/checker"

# The trunk a pipeline checks its commit against, without git: every check
# finds the merge it was given, against a tip seen at `seen_at`, and fetches
# nothing.
class FakeTrunk
  include TrunkKit

  RESULT = FunCi::Trunk::Checker::Result

  # A project that checks no trunk, as with `trunk: none`.
  NONE = Object.new.tap do |none|
    def none.start(_sha, _fetches) = nil
  end.freeze

  def initialize(merge, seen_at: Time.now)
    @merge = merge
    @seen_at = seen_at
  end

  def start(sha, _fetches) = sha
  def finish(sha) = RESULT.new(check: trunk_check(sha, @merge, seen_at: @seen_at), fetched: nil)

  def recheck(heads, tip)
    heads.reject { |_, sha| sha == tip.sha }.keys.map { |commit| FunCi::Trunk::Check.new(commit: commit, tip: tip, merge: @merge) }
  end
end
