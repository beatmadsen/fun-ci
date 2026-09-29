# frozen_string_literal: true

require_relative "project_config"
require_relative "../trunk/description"
require_relative "../trunk/git"

module FunCi
  module Setup
    # The project's trunk as `fun-ci check` describes it. Git is asked only
    # inside a repository: outside one there is no trunk to find.
    class TrunkReport
      NO_REFS = Trunk::Refs.new(remotes: [], branches: [], heads: {})

      def initialize(project_root)
        @project_root = project_root
      end

      def lines
        config = ProjectConfig.new(@project_root)
        Trunk::Description.lines(setting: config.trunk, interval: config.trunk_fetch, refs: refs)
      end

      private

      def refs = File.exist?(File.join(@project_root, ".git")) ? Trunk::Git.new(@project_root).refs : NO_REFS
    end
  end
end
