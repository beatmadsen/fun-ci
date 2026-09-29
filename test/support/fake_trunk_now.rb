# frozen_string_literal: true

require_relative "trunk_kit"

# The trunk as a project's git has it now, without git: its tip at `sha`,
# and every commit checked against it finds `merge`.
class FakeTrunkNow
  include TrunkKit

  attr_accessor :sha, :merge

  def initialize
    @sha = TRUNK_SHA
    @merge = nil
  end

  def now_at(_tip) = @sha
  # Nil while `merge` is, as for a project that checks no trunk.
  def check(commit, _fetches) = @merge && trunk_check(commit, @merge, seen_at: Time.now, sha: @sha)
end
