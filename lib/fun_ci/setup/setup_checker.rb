# frozen_string_literal: true

require_relative "project_config"
require_relative "legacy_hooks"
require_relative "installed_hooks"
require_relative "trunk_report"
require_relative "placeholders"

module FunCi
  module Setup
    class SetupChecker
      # What it warns of: fun-ci 1.x's hooks, any in `hooks_dir` that doesn't
      # run fun-ci, and stage scripts still init's placeholders.
      Hooks = Data.define(:sources) do
        def warnings = sources.flat_map(&:warnings)
      end

      # hooks_dir: where git runs the project's hooks from; nil outside a git repository.
      def self.run(project_root:, stdout: $stdout, hooks_dir: nil)
        sources = [LegacyHooks.new(project_root), InstalledHooks.new(hooks_dir), Placeholders.new(project_root)]
        hooks = Hooks.new(sources)
        new(config: ProjectConfig.new(project_root), hooks: hooks, stdout: stdout,
            trunk: TrunkReport.new(project_root)).run
      end

      # trunk: describes the project's trunk (#lines).
      def initialize(config:, hooks:, stdout:, trunk:)
        @config = config
        @hooks = hooks
        @stdout = stdout
        @trunk = trunk
      end

      # Warnings are printed but don't fail the check.
      def run
        errors = problems
        @stdout.puts(errors.empty? ? "All OK. The project is configured." : errors)
        @stdout.puts(@trunk.lines)
        list_presets
        list_jobs
        @hooks.warnings.each { |warning| @stdout.puts "Warning: #{warning}" }
        errors.empty? ? 0 : 1
      end

      private

      def problems = @config.validate + @config.settings_errors + @config.evidence_errors + @config.job_errors

      def list_presets
        lists = { "this project" => @config.presets, "any project's output" => @config.any_project_presets }
        lists.each { |what, names| @stdout.puts "Evidence presets for #{what}: #{names.join(", ")}" if names.any? }
      end

      def list_jobs
        jobs = @config.jobs
        @stdout.puts "Jobs: #{jobs.map { |job| "#{job.name} (#{job.cadence})" }.join(", ")}" if jobs.any?
      end
    end
  end
end
