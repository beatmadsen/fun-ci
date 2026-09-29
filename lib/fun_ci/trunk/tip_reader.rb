# frozen_string_literal: true

require_relative "check"
require_relative "fetch"
require_relative "resolver"
require_relative "../persistence/trunk_fetches"

module FunCi
  module Trunk
    # The tip of the trunk a check reads, and when it counts as seen
    # (docs/trunk-conflicts.md, Keeping the trunk fresh): fun-ci's own ref once
    # it has fetched one, seen when it was last fetched; else the developer's
    # ref, seen when it last moved.
    class TipReader
      # clock: answers the time now.
      def initialize(git, clock)
        @git = git
        @clock = clock
      end

      # fetching: whether fun-ci fetches this trunk; fetched: how this run's
      # fetch went, if it made one; last: the fetch before it. Nil when the
      # trunk doesn't exist.
      def tip(ref, fetching:, fetched: nil, last: nil)
        own = fetching && ref.remote && @git.rev(Fetch.ref_for(ref))
        return at(ref, own, seen(fetched, last) || @git.moved_at(Fetch.ref_for(ref))) if own

        full = ref.remote ? "refs/remotes/#{ref}" : "refs/heads/#{ref.branch}"
        sha = @git.rev(full)
        sha && at(ref, sha, @git.moved_at(full))
      end

      private

      def seen(fetched, last) = fetched && !fetched.error ? @clock.call : last&.fetched_at
      def at(ref, sha, seen_at) = Tip.new(remote: ref.remote, branch: ref.branch, sha: sha, seen_at: seen_at)
    end
  end
end
