# frozen_string_literal: true

require_relative "project_config"

module FunCi
  module Setup
    class SetupChecker
      def self.run(project_root:, stdout: $stdout)
        new(config: ProjectConfig.new(project_root), stdout: stdout).run
      end

      def initialize(config:, stdout:)
        @config = config
        @stdout = stdout
      end

      def run
        errors = @config.validate
        @stdout.puts(errors.empty? ? "All OK. The project is configured." : errors)
        errors.empty? ? 0 : 1
      end
    end
  end
end
