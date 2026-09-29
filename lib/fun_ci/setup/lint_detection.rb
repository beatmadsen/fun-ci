# frozen_string_literal: true

require_relative "maven_linter_detector"
require_relative "gradle_linter_detector"

module FunCi
  module Setup
    # The lint command init writes in place of the template's, from the source
    # linter the project's build configures; nil keeps the template's.
    module LintDetection
      GRADLE_FILES = %w[build.gradle.kts build.gradle].freeze

      def self.command(detected, project_root)
        case detected
        when :jvm_maven then maven(project_root)
        when :jvm_gradle_kotlin, :jvm_gradle_groovy then gradle(project_root)
        end
      end

      def self.maven(project_root)
        command = MavenLinterDetector.new(File.read(File.join(project_root, "pom.xml"))).lint_command
        command == MavenLinterDetector::DEFAULT_COMMAND ? nil : command
      end

      def self.gradle(project_root)
        file = GRADLE_FILES.map { File.join(project_root, _1) }.find { File.exist?(_1) }
        file && GradleLinterDetector.new(File.read(file)).lint_command
      end
      private_class_method :maven, :gradle
    end
  end
end
