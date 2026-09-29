# frozen_string_literal: true

module FunCi
  module Trunk
    # A branch that may be the trunk: on a remote, or local when remote is nil.
    Ref = Data.define(:remote, :branch)

    class Ref
      def to_s = remote ? "#{remote}/#{branch}" : branch
    end

    # What a repository has to choose a trunk from: its remotes, its branches
    # (a remote's as "origin/main", local ones by name) and each remote's
    # default branch, where git knows it.
    Refs = Data.define(:remotes, :branches, :heads)

    # Which ref is the trunk (docs/trunk-conflicts.md, Which ref is the trunk):
    # the one configured, else the remote's default branch, else the first
    # usual trunk name on the remote, else locally; nil when none exists.
    module Resolver
      USUAL = %w[main master develop development trunk].freeze

      def self.pick(setting, refs)
        return configured(setting, refs.remotes) if setting

        remote = remote(refs.remotes)
        remote ? on_remote(remote, refs) : on_local(refs.branches)
      end

      def self.configured(setting, remotes)
        remote = remotes.find { |name| setting.start_with?("#{name}/") }
        Ref.new(remote: remote, branch: remote ? setting.delete_prefix("#{remote}/") : setting)
      end

      def self.remote(remotes)
        return "origin" if remotes.include?("origin")

        remotes.first if remotes.size == 1
      end

      def self.on_remote(remote, refs)
        branch = refs.heads[remote] || USUAL.find { |name| refs.branches.include?("#{remote}/#{name}") }
        branch && Ref.new(remote: remote, branch: branch)
      end

      def self.on_local(branches)
        branch = USUAL.find { |name| branches.include?(name) }
        branch && Ref.new(remote: nil, branch: branch)
      end
      private_class_method :configured, :remote, :on_remote, :on_local
    end
  end
end
