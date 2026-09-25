# frozen_string_literal: true

require_relative "project_detector"
require_relative "template_writer"
require_relative "maven_linter_detector"

module FunCi
  module Setup
    class Installer
      def self.run(project_root:, stdout: $stdout)
        new(project_root: project_root, stdout: stdout).run
      end

      def initialize(project_root:, stdout:)
        @project_root = project_root
        @stdout = stdout
      end

      def run
        return report(".fun-ci/ already exists, so init did nothing.", 0) if initialised?

        detected = ProjectDetector.new(Dir.children(@project_root)).detect
        return report("Could not detect project type. Create .fun-ci/ manually.", 1) if detected == :unknown

        write_templates(detected)
      end

      private

      def initialised?
        Dir.exist?(File.join(@project_root, ".fun-ci"))
      end

      def write_templates(detected)
        @stdout.puts "Detected: #{detected.to_s.tr("_", " ")}"
        TemplateWriter.new(detected, @project_root, lint_override: detect_maven_linter(detected)).write
        report("Created .fun-ci/ with template scripts.", 0)
      end

      def report(message, exit_code)
        @stdout.puts message
        exit_code
      end

      def detect_maven_linter(detected)
        return nil unless detected == :jvm_maven

        command = MavenLinterDetector.new(File.read(File.join(@project_root, "pom.xml"))).lint_command
        command == MavenLinterDetector::DEFAULT_COMMAND ? nil : command
      end
    end
  end
end
