# frozen_string_literal: true

require_relative "lib/fun_ci/version"

Gem::Specification.new do |spec|
  spec.name = "fun_ci"
  spec.version = FunCi::VERSION
  spec.authors = ["Erik Thyge Madsen"]
  spec.summary = "Opinionated local CI that checks your code before it leaves your machine"
  spec.description = "Opinionated local CI that checks your code before it leaves your machine. " \
                     "Runs a four-stage pipeline (lint, build, fast tests, slow tests) on every commit " \
                     "with strict time budgets. Hooks into git pre-commit and pre-push, " \
                     "stores results in SQLite, and includes a TUI dashboard for monitoring."
  spec.homepage = "https://github.com/beatmadsen/fun-ci"
  spec.license = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "#{spec.homepage}#readme",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.2"

  # Tracked files only, so nothing lying around uncommitted in lib/ ships.
  spec.files = IO.popen(%w[git ls-files -z -- lib exe LICENSE.txt README.md CHANGELOG.md], chdir: __dir__, &:read)
                 .split("\x0")
  spec.bindir = "exe"
  spec.executables = %w[fun-ci fun-ci-trigger fun-ci-tui]
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3", "~> 2.0"
end
