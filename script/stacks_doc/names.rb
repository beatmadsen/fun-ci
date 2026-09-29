# frozen_string_literal: true

module StacksDoc
  # What people call each stack `fun-ci init` knows: its family, and the
  # variant where the family has several.
  module Names
    STACKS = {
      ruby_rspec: %w[Ruby rspec], ruby_bundler: %w[Ruby rake],
      jvm_gradle_kotlin: ["Gradle", "Kotlin DSL"], jvm_gradle_groovy: ["Gradle", "Groovy DSL"], jvm_maven: ["Maven"],
      rust_cargo: ["Rust"], go: ["Go"], elixir_mix: ["Elixir"], dart: ["Dart"], swift: ["Swift"],
      php_composer: ["PHP"], dotnet: [".NET"],
      python_uv: %w[Python uv], python_poetry: %w[Python Poetry], python: %w[Python pip],
      deno: ["Deno"], bun: ["Bun"], node_pnpm: %w[Node pnpm], node_yarn: %w[Node Yarn], node_npm: %w[Node npm],
      perl: ["Perl"], cmake: ["C and C++", "CMake"], make: ["C and C++", "make"]
    }.freeze

    def self.family(id) = STACKS.fetch(id).first

    def self.stack(id)
      family, variant = STACKS.fetch(id)
      variant ? "#{family} (#{variant})" : family
    end
  end
end
