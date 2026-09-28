# frozen_string_literal: true

require_relative "lib/fun_ci/version"

Gem::Specification.new do |spec|
  spec.name = "fun_ci"
  spec.version = FunCi::VERSION
  spec.authors = ["Erik Thyge Madsen"]
  spec.summary = "Opinionated local CI that checks every commit on your machine, for you to watch " \
                 "and for your coding agent to ask"
  spec.description = "Opinionated local CI that checks your code before it leaves your machine. " \
                     "After every commit a git hook runs four stages in a worktree at that commit: " \
                     "lint and build in parallel, then a fast suite, with a slow suite in the background, " \
                     "each held to a strict time budget (30 s, 30 s, 10 s and 5 minutes). " \
                     "The pre-push hook stops a push whose lint, build or fast suite failed. " \
                     "There are two ways in. People watch fun-ci console, a terminal dashboard drawn in " \
                     "24-bit colour by a Rust renderer (included in the Linux and macOS gems), where each " \
                     "milestone of a run plays its own scene: a rocket while it runs, fireworks when it " \
                     "passes, an explosion when it fails, and a quiet night scene when nothing has run " \
                     "for a while. Coding agents and scripts ask with commands that answer in exit codes: " \
                     "fun-ci wait blocks until a commit's verdict is in, and fun-ci why prints what was " \
                     "kept about a failure (the failures a test runner reported, excerpts picked out by " \
                     "presets for 34 tools, log lines, the end of the output, with secrets masked), so " \
                     "nobody has to run a suite again to see what broke. Results are kept in SQLite. " \
                     "Any language works, since the stages are shell scripts; fun-ci init writes them " \
                     "for Ruby, Gradle and Maven projects."
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
  spec.executables = %w[fun-ci]
  spec.require_paths = ["lib"]

  spec.add_dependency "rexml", "~> 3.2"
  spec.add_dependency "sqlite3", "~> 2.0"
end
