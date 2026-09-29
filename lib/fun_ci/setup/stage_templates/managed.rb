# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # Stacks that run on a virtual machine: the JVM, .NET, the BEAM and Dart's.
    module StageTemplates
      NO_GRADLE_LINTER = 'echo "No source linter in the build: put ktlint, spotless or detekt in .fun-ci/lint.sh"'

      GRADLE = stages(NO_GRADLE_LINTER, "./gradlew assemble testClasses",
                      "./gradlew test", "./gradlew integrationTest").freeze

      MANAGED = {
        jvm_gradle_kotlin: GRADLE,
        jvm_gradle_groovy: GRADLE,
        jvm_maven: stages("mvn validate", "mvn test-compile", "mvn surefire:test",
                          "mvn failsafe:integration-test failsafe:verify"),
        dotnet: stages("dotnet format whitespace --folder --verify-no-changes", "dotnet build",
                       'dotnet test --no-build --filter "Category!=Slow"',
                       'dotnet test --no-build --filter "Category=Slow"'),
        elixir_mix: stages("mix format --check-formatted", "mix deps.get && MIX_ENV=test mix compile",
                           "mix test --exclude slow", "mix test --only slow"),
        dart: stages("dart analyze", "dart pub get --precompile", "dart test --exclude-tags slow",
                     "dart test --compiler source --tags slow")
      }.freeze
    end
  end
end
