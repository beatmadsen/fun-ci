# frozen_string_literal: true

require "shellwords"
require_relative "settings"
require_relative "../evidence/settings"
require_relative "../evidence/start"
require_relative "../jobs/folders"

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

      # What stops a pipeline: no .fun-ci/, or a stage script it can't run.
      def validate
        return ["No .fun-ci/ folder found in #{@project_root}"] unless folder_exists?

        REQUIRED_SCRIPTS.flat_map { |script| script_errors(script) }
      end

      # Mistakes in .fun-ci/config, which never stop a pipeline: the setting
      # takes its default instead.
      def settings_errors = settings.errors

      # Mistakes in the `evidence` key, which `fun-ci check` reports but which
      # never stop a pipeline: the entry with the mistake is left out instead.
      def evidence_errors = Evidence::Settings.load(File.join(@fun_ci_dir, "config")).errors(root: @project_root)

      # The presets whose markers the project has, which run when a stage fails
      # and its output shows their tool.
      def presets = preset_candidates.select(&:because).map { |found| found.preset.name }

      # The presets without markers, which read what any project's output
      # may hold, such as JSON logs.
      def any_project_presets = preset_candidates.reject(&:because).map { |found| found.preset.name }

      # The daily and weekly jobs that can run, and why any other can't
      # (design.md, Daily and weekly jobs); neither stops a pipeline.
      def jobs = Jobs::Folders.new(@project_root).jobs
      def job_errors = Jobs::Folders.new(@project_root).errors

      def worktree_slots = settings.worktree_slots
      def trunk = settings.trunk
      def trunk_fetch = settings.trunk_fetch
      def job_spacing = settings.job_spacing

      def script_path(stage)
        File.join(@fun_ci_dir, "#{stage}.sh")
      end

      # The shell command that runs a stage's script on a commit, its path
      # quoted, since a project's path may hold spaces.
      def stage_command(stage, sha) = "#{Shellwords.escape(script_path(stage))} #{sha}"

      private

      def settings = Settings.at(File.join(@fun_ci_dir, "config"))

      def preset_candidates
        evidence = Evidence::Settings.load(File.join(@fun_ci_dir, "config"))
        Evidence::Start.candidates(Evidence::Worktree.new(@project_root), evidence, "all")
      end

      def script_errors(script)
        path = File.join(@fun_ci_dir, script)
        return [".fun-ci/#{script} is not found"] unless File.exist?(path)
        return [".fun-ci/#{script} is not executable"] unless File.executable?(path)

        []
      end
    end
  end
end
