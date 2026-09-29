# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "check"
require_relative "git"
require_relative "merge_check"
require_relative "resolver"

module FunCi
  module Trunk
    # Checks a commit against the project's trunk (docs/trunk-conflicts.md):
    # the ref `trunk:` names in .fun-ci/config, or the one the repository
    # has; no check at all when it says `none`.
    class Checker
      SET_IT = "set trunk: in .fun-ci/config"

      def self.for(project) = new(Git.new(project), Setup::ProjectConfig.new(project))

      # config: answers #trunk, the name .fun-ci/config gives, or nil.
      def initialize(git, config)
        @git = git
        @config = config
      end

      # A Trunk::Check, or nil when the project checks no trunk.
      def check(sha)
        setting = @config.trunk
        return nil if setting == "none"

        ref = Resolver.pick(setting, @git.refs)
        ref ? against(sha, ref) : unknown(sha, "no trunk found; #{SET_IT}")
      end

      private

      def against(sha, ref)
        full = ref.remote ? "refs/remotes/#{ref}" : "refs/heads/#{ref.branch}"
        tip_sha = @git.rev(full)
        return unknown(sha, "#{ref} doesn't exist; #{SET_IT}") unless tip_sha

        tip = Tip.new(remote: ref.remote, branch: ref.branch, sha: tip_sha, seen_at: @git.moved_at(full))
        Check.new(commit: sha, tip: tip, merge: MergeCheck.new(@git).merge(sha, tip_sha, ref.to_s))
      end

      def unknown(sha, reason) = Check.new(commit: sha, tip: nil, merge: Merge.unknown(reason))
    end
  end
end
