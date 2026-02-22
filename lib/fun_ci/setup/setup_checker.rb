# frozen_string_literal: true

require_relative "project_config"

module FunCi
  module Setup
    class SetupChecker
      def self.run(project_root:, stdout: $stdout, stderr: $stderr)
        new(project_root: project_root, stdout: stdout).run
      end

      def initialize(project_root:, stdout:)
        @config = ProjectConfig.new(project_root)
        @stdout = stdout
      end

      def run
        errors = @config.validate

        if errors.empty?
          @stdout.puts "All OK — project is configured."
          0
        else
          errors.each { |e| @stdout.puts e }
          1
        end
      end
    end
  end
end
