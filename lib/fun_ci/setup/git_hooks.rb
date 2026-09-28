# frozen_string_literal: true

require "open3"
require_relative "../pipeline/git_environment"

module FunCi
  module Setup
    # Where git runs a project's hooks from: its git directory's hooks, or
    # where core.hooksPath points, and from a linked worktree the
    # repository's own. Git is asked, as .git may be a file or be ignored.
    module GitHooks
      # The directory, or nil outside a git repository.
      def self.dir(project_root)
        out, status = Open3.capture2(Pipeline::GitEnvironment::CLEAN, "git", "rev-parse", "--git-path", "hooks",
                                     chdir: project_root, err: File::NULL)
        status.success? ? File.expand_path(out.strip, project_root) : nil
      end
    end
  end
end
