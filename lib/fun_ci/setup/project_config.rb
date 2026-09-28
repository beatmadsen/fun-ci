# frozen_string_literal: true

require "shellwords"
require_relative "settings"
require_relative "../evidence/settings"
require_relative "../evidence/start"

module FunCi
  module Setup
    class ProjectConfig
      REQUIRED_SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

      def initialize(project_root)
        @project_root = project_root
        @fun_ci_dir = File.join(project_root, ".fun-ci")
      end

      def folder_exists?
        Dir.exist?(@fun_ci_dir)
      end

      def validate
        return ["No .fun-ci/ folder found in #{@project_root}"] unless folder_exists?

        REQUIRED_SCRIPTS.flat_map { |script| script_errors(script) } + settings.errors
      end

      # Mistakes in the `evidence` key, which `fun-ci check` reports but which
      # never stop a pipeline: the entry with the mistake is left out instead.
      def evidence_errors = Evidence::Settings.load(File.join(@fun_ci_dir, "config")).errors(root: @project_root)

      # The presets whose markers the project has, which run when a stage fails
      # and its output shows their tool.
      def presets
        settings = Evidence::Settings.load(File.join(@fun_ci_dir, "config"))
        Evidence::Start.candidates(Evidence::Worktree.new(@project_root), settings, "all").map { |found| found.preset.name }
      end

      def worktree_slots = settings.worktree_slots

      def script_path(stage)
        File.join(@fun_ci_dir, "#{stage}.sh")
      end

      # The shell command that runs a stage's script on a commit, its path
      # quoted, since a project's path may hold spaces.
      def stage_command(stage, sha) = "#{Shellwords.escape(script_path(stage))} #{sha}"

      private

      def settings = Settings.new(File.join(@fun_ci_dir, "config"))

      def script_errors(script)
        path = File.join(@fun_ci_dir, script)
        return [".fun-ci/#{script} is not found"] unless File.exist?(path)
        return [".fun-ci/#{script} is not executable"] unless File.executable?(path)

        []
      end
    end
  end
end
