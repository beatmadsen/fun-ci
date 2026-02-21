# frozen_string_literal: true

require_relative "lib/fun_ci"

Gem::Specification.new do |spec|
  spec.name = "fun_ci"
  spec.version = FunCi::VERSION
  spec.authors = ["Erik Thyge Madsen"]
  spec.summary = "Opinionated, local-first CI for Ruby projects"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["fun-ci", "fun-ci-trigger", "fun-ci-tui"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3"
end
