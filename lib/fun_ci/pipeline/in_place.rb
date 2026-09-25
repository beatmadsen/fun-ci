# frozen_string_literal: true

require_relative "slot"

module FunCi
  module Pipeline
    # A workspace that is the project directory itself, with nothing to lock.
    # For a root commit's null SHA, which no worktree can check out.
    InPlace = Data.define(:path)

    class InPlace
      Unlocked = Struct.new(:closed?) { def close = nil }

      def acquire(_sha) = Slot.new(path, Unlocked.new(false))
    end
  end
end
