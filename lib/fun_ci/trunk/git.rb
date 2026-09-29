# frozen_string_literal: true

require "open3"
require "tmpdir"
require_relative "../pipeline/git_environment"
require_relative "merge_check"
require_relative "resolver"

module FunCi
  module Trunk
    # The git the trunk check asks, in the project's repository. A merge
    # writes its tree and conflicted blobs into a scratch object directory
    # that borrows the repository's objects, so the repository keeps nothing.
    class Git
      REF_PREFIXES = %w[refs/heads/ refs/remotes/].freeze

      def initialize(dir)
        @dir = dir
      end

      def counts(commit, trunk) = run("rev-list", "--left-right", "--count", "#{commit}...#{trunk}")

      def merge_tree(commit, trunk)
        Dir.mktmpdir("fun-ci-merge") do |scratch|
          env = { "GIT_OBJECT_DIRECTORY" => scratch, "GIT_ALTERNATE_OBJECT_DIRECTORIES" => objects }
          run("merge-tree", "--write-tree", "--name-only", "--messages", commit, trunk, env: env)
        end
      end

      def version = run("--version").out[/\d+(?:\.\d+)+/]

      def refs
        remotes = run("remote").out.split
        Refs.new(remotes: remotes, branches: branches, heads: remotes.to_h { |remote| [remote, head(remote)] }.compact)
      end

      # The commit a ref names, or nil when there is no such ref.
      def rev(ref)
        answer = run("rev-parse", "--verify", "--quiet", "#{ref}^{commit}")
        answer.status.zero? ? answer.out.strip : nil
      end

      # When the ref last moved, from its reflog, or else when its commit was made.
      def moved_at(ref)
        moved = run("reflog", "-1", "--date=unix", "--format=%gd", ref).out[/@\{(\d+)\}/, 1]
        Time.at(Integer(moved || run("log", "-1", "--format=%ct", ref).out.strip))
      end

      private

      def branches
        names = run("for-each-ref", "--format=%(refname)", *REF_PREFIXES).out.split("\n")
        names.reject { |name| name.end_with?("/HEAD") }.map { |name| strip_prefix(name) }
      end

      def strip_prefix(name) = REF_PREFIXES.reduce(name) { |short, prefix| short.delete_prefix(prefix) }

      def head(remote)
        answer = run("symbolic-ref", "--quiet", "refs/remotes/#{remote}/HEAD")
        answer.status.zero? ? answer.out.strip.delete_prefix("refs/remotes/#{remote}/") : nil
      end

      def objects = File.expand_path(File.join(run("rev-parse", "--git-common-dir").out.strip, "objects"), @dir)

      def run(*, env: {})
        out, err, status = Open3.capture3(Pipeline::GitEnvironment::CLEAN.merge(env), "git", *, chdir: @dir)
        MergeCheck::Answer.new(status: status.exitstatus, out: out, err: err)
      end
    end
  end
end
