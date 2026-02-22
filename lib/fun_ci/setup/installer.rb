# frozen_string_literal: true

require_relative "project_detector"
require_relative "template_writer"
require_relative "maven_linter_detector"

module FunCi
  module Setup
    class Installer
      def self.run(project_root:, stdout: $stdout, pom_reader: nil)
        new(project_root: project_root, stdout: stdout, pom_reader: pom_reader).run
      end

      def initialize(project_root:, stdout:, pom_reader: nil)
        @project_root = project_root
        @stdout = stdout
        @pom_reader = pom_reader || ->(path) { File.read(path) }
      end

      def run
        if Dir.exist?(File.join(@project_root, ".fun-ci"))
          @stdout.puts ".fun-ci/ already exists — skipping init."
          return 0
        end

        filenames = Dir.children(@project_root)
        detected = ProjectDetector.new(filenames).detect

        if detected == :unknown
          @stdout.puts "Could not detect project type. Create .fun-ci/ manually."
          return 1
        end

        @stdout.puts "Detected: #{detected.to_s.tr("_", " ")}"

        lint_override = detect_maven_linter(detected)
        TemplateWriter.new(detected, @project_root, lint_override: lint_override).write

        @stdout.puts "Created .fun-ci/ with template scripts."
        0
      end

      private

      def detect_maven_linter(detected)
        return nil unless detected == :jvm_maven

        pom_path = File.join(@project_root, "pom.xml")
        pom_content = @pom_reader.call(pom_path)
        command = MavenLinterDetector.new(pom_content).lint_command
        command == MavenLinterDetector::DEFAULT_COMMAND ? nil : command
      end
    end
  end
end
