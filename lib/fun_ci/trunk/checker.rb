# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "check"
require_relative "fetch"
require_relative "git"
require_relative "merge_check"
require_relative "resolver"
require_relative "tip_reader"

module FunCi
  module Trunk
    # Checks a commit against the project's trunk (docs/trunk-conflicts.md):
    # the ref `trunk:` names in .fun-ci/config, or the one the repository
    # has; none at all when it says `none`. A check starts where the database
    # may be used (resolving the trunk, claiming a fetch, recording its pid)
    # and finishes where it may not (waiting for the fetch, merging).
    class Checker
      SET_IT = "set trunk: in .fun-ci/config"

      # What a check found, or nil for none, and how its fetch went, or nil when it made none.
      Result = Data.define(:check, :fetched)
      # A check begun: the trunk it found (nil for none), its fetch if started, and the fetch before it.
      Pending = Data.define(:sha, :ref, :started, :last)

      def self.for(project, env: ENV.to_h)
        new(Git.new(project), Setup::ProjectConfig.new(project), Fetch.new(project, env: env), -> { Time.now })
      end

      # config: answers #trunk and #trunk_fetch; fetch: starts and finishes a Fetch; clock: answers the time.
      def initialize(git, config, fetch, clock)
        @git = git
        @config = config
        @fetch = fetch
        @clock = clock
      end

      # fetches: claims a fetch and knows the last (Persistence::TrunkFetches). Yields a fetch's pid.
      # Nil when the project checks no trunk.
      def start(sha, fetches, &)
        setting = @config.trunk
        return nil if setting == "none"

        ref = Resolver.pick(setting, @git.refs)
        started = fetch?(ref, fetches) ? @fetch.start(ref, &) : nil
        Pending.new(sha: sha, ref: ref, started: started, last: fetches.last)
      end

      def finish(pending)
        return Result.new(check: unknown(pending.sha, "no trunk found; #{SET_IT}"), fetched: nil) unless pending.ref

        fetched = pending.started && @fetch.finish(pending.started, deadline: FETCH_DEADLINE)
        Result.new(check: against(pending, fetched), fetched: fetched)
      end

      private

      def fetch?(ref, fetches)
        interval = @config.trunk_fetch
        ref&.remote && interval && fetches.claim(now: @clock.call, interval: interval)
      end

      def against(pending, fetched)
        ref = pending.ref
        tip = TipReader.new(@git, @clock).tip(ref, fetching: !@config.trunk_fetch.nil?, fetched: fetched,
                                                   last: pending.last)
        return unknown(pending.sha, "#{ref} doesn't exist; #{SET_IT}") unless tip

        Check.new(commit: pending.sha, tip: tip, merge: MergeCheck.new(@git).merge(pending.sha, tip.sha, ref.to_s))
      end

      def unknown(sha, reason) = Check.new(commit: sha, tip: nil, merge: Merge.unknown(reason))
    end
  end
end
