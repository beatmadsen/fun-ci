# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "checker"
require_relative "git"
require_relative "tip_reader"

module FunCi
  module Trunk
    # The trunk as the project's git has it now, for the agent commands
    # (architecture.md, Checking against the trunk): where
    # its ref points, read the way a check reads it, and a check against it
    # that never fetches, since a command an agent runs must not wait on the network.
    class Local
      # Lets no fetch go, and knows the last one.
      NoFetch = Data.define(:fetches) do
        def claim(**) = nil
        def last = fetches.last
      end

      # dir: the project's directory, or one inside it.
      def initialize(dir)
        @dir = dir
      end

      # The SHA the tip's trunk points at now, or nil when it is gone.
      def now_at(tip)
        ref = Ref.new(remote: tip.remote, branch: tip.branch)
        TipReader.new(git, -> { Time.now }).tip(ref, fetching: !config.trunk_fetch.nil?)&.sha
      end

      # fetches: the project's (Persistence::TrunkFetches), for when the last fetch was.
      def check(sha, fetches)
        checker = Checker.for(root)
        pending = checker.start(sha, NoFetch.new(fetches: fetches))
        pending && checker.finish(pending).check
      end

      # The conflict between the commit and the tip it was checked against, merged
      # again; nil when either is gone from the repository (a force push, then gc).
      def explain(sha, tip)
        return nil unless git.rev(sha) && git.rev(tip.sha)

        git.explain(sha, tip.sha)
      end

      private

      def root = @root ||= Git.new(@dir).toplevel || @dir
      def git = Git.new(root)
      def config = Setup::ProjectConfig.new(root)
    end
  end
end
