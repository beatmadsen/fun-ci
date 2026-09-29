# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "../persistence/trunk_fetches"
require_relative "description"
require_relative "git"
require_relative "resolver"

module FunCi
  module Trunk
    # What to say before a project's first fetch of its trunk, where the
    # developer sees it (docs/trunk-conflicts.md, Keeping the trunk fresh):
    # the post-commit hook's run is in the background, and what it prints is not.
    module FirstFetch
      # Nil unless the project fetches a remote trunk and never has yet.
      def self.notice(project, db)
        config = Setup::ProjectConfig.new(project)
        interval = config.trunk_fetch
        return nil if interval.nil? || config.trunk == "none" || Persistence::TrunkFetches.new(db, project).last

        ref = Resolver.pick(config.trunk, Git.new(project).refs)
        ref&.remote ? Description.first_fetch(ref, interval) : nil
      end
    end
  end
end
