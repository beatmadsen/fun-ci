# frozen_string_literal: true

require_relative "lib/fun_ci"

Gem::Specification.new do |spec|
  spec.name = "fun_ci"
  spec.version = FunCi::VERSION
  spec.authors = ["Erik Thyge Madsen"]
  spec.summary = "Opinionated local CI that checks your code before it leaves your machine"
  spec.homepage = "https://github.com/beatmadsen/fun-ci"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["fun-ci", "fun-ci-trigger", "fun-ci-tui"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3"
end
