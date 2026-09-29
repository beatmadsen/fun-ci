# frozen_string_literal: true

module FunCi
  module Setup
    # Which kind of project a directory is, from the names at its top: the
    # first stack, in this order, any of whose markers is there. A marker is a
    # name, a glob, or a list of them that must all be there. A language
    # comes before the tooling that sits beside it (Node beside Python, a
    # Makefile around Go), and a lockfile picks the package manager.
    class ProjectDetector
      STACKS = {
        ruby_rspec: [%w[Gemfile spec], %w[Gemfile .rspec]],
        ruby_bundler: ["Gemfile"],
        jvm_gradle_kotlin: %w[build.gradle.kts settings.gradle.kts],
        jvm_gradle_groovy: %w[build.gradle settings.gradle],
        jvm_maven: ["pom.xml"],
        rust_cargo: ["Cargo.toml"],
        go: ["go.mod"],
        elixir_mix: ["mix.exs"],
        dart: ["pubspec.yaml"],
        swift: ["Package.swift"],
        php_composer: ["composer.json"],
        dotnet: %w[*.sln *.csproj *.fsproj],
        python_uv: ["uv.lock"],
        python_poetry: ["poetry.lock"],
        python: %w[pyproject.toml setup.py setup.cfg requirements.txt],
        deno: %w[deno.json deno.jsonc],
        bun: %w[bun.lock bun.lockb bunfig.toml],
        node_pnpm: ["pnpm-lock.yaml"],
        node_yarn: ["yarn.lock"],
        node_npm: ["package.json"],
        perl: %w[cpanfile Makefile.PL Build.PL dist.ini],
        cmake: ["CMakeLists.txt"],
        make: %w[Makefile makefile GNUmakefile]
      }.freeze

      def initialize(filenames)
        @filenames = filenames
      end

      def detect
        STACKS.find { |_, markers| markers.any? { |marker| present?(marker) } }&.first || :unknown
      end

      private

      def present?(marker)
        Array(marker).all? { |part| @filenames.any? { |name| names?(part, name) } }
      end

      def names?(part, name) = File.fnmatch?(part, name)
    end
  end
end
