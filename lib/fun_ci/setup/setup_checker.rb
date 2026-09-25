# frozen_string_literal: true

require_relative "project_config"
require_relative "legacy_hooks"

module FunCi
  module Setup
    class SetupChecker
      def self.run(project_root:, stdout: $stdout)
        new(config: ProjectConfig.new(project_root), hooks: LegacyHooks.new(project_root), stdout: stdout).run
      end

      def initialize(config:, hooks:, stdout:)
        @config = config
        @hooks = hooks
        @stdout = stdout
      end

      # Warnings are printed but don't fail the check.
      def run
        errors = @config.validate
        @stdout.puts(errors.empty? ? "All OK. The project is configured." : errors)
        @hooks.warnings.each { |warning| @stdout.puts "Warning: #{warning}" }
        errors.empty? ? 0 : 1
      end
    end
  end
end
