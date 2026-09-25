# frozen_string_literal: true

require "open3"
require_relative "git_environment"

module FunCi
  module Pipeline
    # The git commands a worktree slot needs, run against the project's repository.
    class Worktrees
      class GitError < StandardError; end

      def initialize(project_root)
        @project_root = project_root
      end

      def root
        File.join(File.expand_path(git(@project_root, "rev-parse", "--git-common-dir").strip, @project_root),
                  "fun-ci", "worktrees")
      end

      # Leaves +path+ as a clean detached checkout of +sha+. Ignored files stay,
      # so caches such as vendor/bundle survive between runs in the same slot.
      def check_out(path, sha)
        return add(path, sha) unless File.exist?(File.join(path, ".git"))

        git(path, "checkout", "--detach", "--force", sha)
        git(path, "clean", "-fd")
      end

      # Has git forget the worktrees whose directories are gone.
      def prune = git(@project_root, "worktree", "prune")

      private

      def add(path, sha) = git(@project_root, "worktree", "add", "--detach", "--force", path, sha)

      def git(dir, *args)
        output, status = Open3.capture2e(GitEnvironment::CLEAN, "git", *args, chdir: dir)
        raise GitError, "git #{args.join(" ")}: #{output}" unless status.success?

        output
      end
    end
  end
end
