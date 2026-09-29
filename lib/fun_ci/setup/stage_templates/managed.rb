# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # Stacks that run on a virtual machine: the JVM, .NET, the BEAM and Dart's.
    module StageTemplates
      GRADLE = stages(
        "./gradlew check -x test",
        "./gradlew assemble",
        reporting("./gradlew test", "build/test-results/test"),
        reporting("./gradlew integrationTest", "build/test-results/integrationTest")
      ).freeze

      MANAGED = {
        jvm_gradle_kotlin: GRADLE,
        jvm_gradle_groovy: GRADLE,
        jvm_maven: stages(
          "mvn verify -DskipTests",
          "mvn compile",
          reporting("mvn test", "target/surefire-reports"),
          reporting("mvn verify", "target/surefire-reports", "target/failsafe-reports")
        ),
        dotnet: stages("dotnet format --verify-no-changes", "dotnet build",
                       'dotnet test --filter "Category!=Slow"', 'dotnet test --filter "Category=Slow"'),
        elixir_mix: stages("mix format --check-formatted", "mix deps.get && mix compile",
                           "mix test --exclude slow", "mix test --only slow"),
        dart: stages("dart analyze", "dart pub get", "dart test --exclude-tags slow", "dart test --tags slow")
      }.freeze
    end
  end
end
