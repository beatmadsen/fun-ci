# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "worktree_pool"
require_relative "in_place"

module FunCi
  module Pipeline
    # Where a pipeline for a commit runs: a slot from the project's worktree
    # pool, sized by .fun-ci/config, or, for a root commit's null SHA, which
    # no worktree can check out, the project directory itself.
    module Workspaces
      NULL_SHA = ("0" * 40).freeze

      def self.for(project, sha)
        return InPlace.new(project) if sha == NULL_SHA

        WorktreePool.new(Worktrees.new(project), size: Setup::ProjectConfig.new(project).worktree_slots)
      end
    end
  end
end
