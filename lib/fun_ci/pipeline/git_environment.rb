# frozen_string_literal: true

module FunCi
  module Pipeline
    # Git runs hooks with variables naming the repository and index that ran
    # them. Passed on, they would point fun-ci's git commands and the stage
    # scripts in a worktree at the checkout's index instead of their own.
    module GitEnvironment
      REPOSITORY = %w[GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
                      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE].freeze

      # An environment for spawn that unsets each of them.
      CLEAN = REPOSITORY.to_h { |name| [name, nil] }.freeze
    end
  end
end
