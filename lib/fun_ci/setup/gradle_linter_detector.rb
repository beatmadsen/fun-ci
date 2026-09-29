# frozen_string_literal: true

module FunCi
  module Setup
    # The source linter a Gradle build applies, whose task lint.sh runs. Lint
    # runs beside the build on the source alone (design.md, Stages side by
    # side), so only linters that compile nothing are named here.
    class GradleLinterDetector
      LINTERS = [
        { plugin: "org.jlleitschuh.gradle.ktlint", command: "./gradlew ktlintCheck" },
        { plugin: "com.diffplug.spotless", command: "./gradlew spotlessCheck" },
        { plugin: "io.gitlab.arturbosch.detekt", command: "./gradlew detekt" }
      ].freeze

      def initialize(build_file)
        @build_file = build_file
      end

      # The linter's command, or nil for a build that applies none.
      def lint_command = LINTERS.find { |linter| @build_file.include?(linter[:plugin]) }&.fetch(:command)
    end
  end
end
