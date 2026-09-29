# frozen_string_literal: true

require_relative "trunk_kit"
require "fun_ci/trunk/checker"

# A trunk whose check can't finish until the fast suite starts, which is
# after the slow suite has forked; the wait has a deadline, so a run that
# never starts the fast suite fails the test rather than hanging it.
class CheckAcrossTheFork
  include TrunkKit

  def initialize(fast_started) = @fast_started = fast_started
  def start(sha, _fetches) = sha
  def notice(_pending) = nil
  def recheck(_heads, _tip) = []

  def finish(sha)
    @fast_started.pop(timeout: 30) || raise("the fast suite never started")
    FunCi::Trunk::Checker::Result.new(check: trunk_check(sha, MERGE.clean(ahead: 1, behind: 1), seen_at: Time.now),
                                      fetched: nil)
  end
end
