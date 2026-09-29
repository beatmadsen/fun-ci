# frozen_string_literal: true

require_relative "trunk_kit"

# The trunk a pipeline checks its commit against, without git: every check
# finds the merge it was given, against a tip seen at `seen_at`.
class FakeTrunk
  include TrunkKit

  # A project that checks no trunk, as with `trunk: none`.
  NONE = Object.new.tap { |none| def none.check(_sha) = nil }.freeze

  attr_reader :checked

  def initialize(merge, seen_at: Time.now)
    @merge = merge
    @seen_at = seen_at
    @checked = []
  end

  def check(sha)
    @checked << sha
    trunk_check(sha, @merge, seen_at: @seen_at)
  end
end
