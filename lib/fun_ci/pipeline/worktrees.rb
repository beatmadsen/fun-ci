# frozen_string_literal: true

require "open3"
require "digest"
require_relative "git_environment"
require_relative "../persistence/state_dir"

module FunCi
  module Pipeline
    # The git commands a worktree slot needs, run against the project's
    # repository. The worktrees live in fun-ci's state directory, one place
    # per repository (all its git worktrees share it), and not under .git/,
    # which tools such as Vite refuse to serve files from.
    class Worktrees
      class GitError < StandardError; end

      # state_dir: fun-ci's own (Persistence::StateDir).
      def initialize(project_root, state_dir: Persistence::StateDir.path(ENV))
        @project_root = project_root
        @state_dir = state_dir
      end

      def root = File.join(fun_ci_dir, "worktrees")

      # Where each daily and weekly job has a worktree of its own (Jobs::Locks).
      def jobs_root = File.join(fun_ci_dir, "jobs")

      # Where fun-ci before 2.4 kept the worktrees: under the git directory.
      def legacy_dir = File.join(common_dir, "fun-ci")

      # Leaves +path+ as a clean detached checkout of +sha+. Ignored files stay,
      # so caches such as vendor/bundle survive between runs in the same slot.
      # Answers whether it made the worktree, which then has no caches.
      def check_out(path, sha)
        return add(path, sha).then { true } unless File.exist?(File.join(path, ".git"))

        git(path, "checkout", "--detach", "--force", sha)
        git(path, "clean", "-fd")
        false
      end

      # Has git forget the worktrees whose directories are gone.
      def prune = git(@project_root, "worktree", "prune")

      private

      # <state>/projects/<repository's name>-<digest of its git directory>.
      def fun_ci_dir
        common = common_dir
        name = File.basename(File.dirname(common))
        File.join(@state_dir, "projects", "#{name}-#{Digest::SHA256.hexdigest(common)[0, 12]}")
      end

      def common_dir
        File.realpath(File.expand_path(git(@project_root, "rev-parse", "--git-common-dir").strip, @project_root))
      end

      def add(path, sha) = git(@project_root, "worktree", "add", "--detach", "--force", path, sha)

      def git(dir, *args)
        output, status = Open3.capture2e(GitEnvironment::CLEAN, "git", *args, chdir: dir)
        raise GitError, "git #{args.join(" ")}: #{output}" unless status.success?

        output
      end
    end
  end
end
