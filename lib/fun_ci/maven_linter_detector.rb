# frozen_string_literal: true

module FunCi
  class MavenLinterDetector
    LINTERS = [
      { artifact_id: "detekt-maven-plugin", command: "mvn detekt:check" },
      { artifact_id: "ktlint-maven-plugin", command: "mvn ktlint:check" },
      { artifact_id: "maven-checkstyle-plugin", command: "mvn checkstyle:check" },
      { artifact_id: "spotbugs-maven-plugin", command: "mvn spotbugs:check" },
      { artifact_id: "maven-pmd-plugin", command: "mvn pmd:check" }
    ].freeze

    DEFAULT_COMMAND = "mvn verify -DskipTests"

    def initialize(pom_content)
      @pom_content = pom_content
    end

    def lint_command
      match = LINTERS.find { |linter| @pom_content.include?(linter[:artifact_id]) }
      match ? match[:command] : DEFAULT_COMMAND
    end
  end
end
