# frozen_string_literal: true

# Which stack each preset reads, as `fun-ci init` names it, and which of that
# stack's stage scripts runs the preset's tool: nil when none does, as for a
# type checker the stack's scripts leave to the project (AT-10.21). FORMATS
# are the presets that read what any stack may print.
module PresetStacks
  Placed = Data.define(:stack, :stage)

  STACKS = {
    "bun-test" => Placed.new(:bun, "fast.sh"),
    "cargo-test" => Placed.new(:rust_cargo, "fast.sh"),
    "dart-test" => Placed.new(:dart, "fast.sh"),
    "deno-test" => Placed.new(:deno, "fast.sh"),
    "dotnet-test" => Placed.new(:dotnet, "fast.sh"),
    "eslint" => Placed.new(:node_npm, "lint.sh"),
    "exunit" => Placed.new(:elixir_mix, "fast.sh"),
    "gcc" => Placed.new(:make, "build.sh"),
    "go-build" => Placed.new(:go, "build.sh"),
    "go-test" => Placed.new(:go, "fast.sh"),
    "gradle" => Placed.new(:jvm_gradle_kotlin, "fast.sh"),
    "gtest" => Placed.new(:cmake, "fast.sh"),
    "jest" => Placed.new(:node_npm, "fast.sh"),
    "maven" => Placed.new(:jvm_maven, "fast.sh"),
    "minitest" => Placed.new(:ruby_bundler, "fast.sh"),
    "mocha" => Placed.new(:node_npm, "fast.sh"),
    "mypy" => Placed.new(:python, nil),
    "node-test" => Placed.new(:node_npm, "fast.sh"),
    "phpunit" => Placed.new(:php_composer, "fast.sh"),
    "pino" => Placed.new(:node_npm, nil),
    "prove" => Placed.new(:perl, "fast.sh"),
    "pytest" => Placed.new(:python, "fast.sh"),
    "rspec" => Placed.new(:ruby_rspec, "fast.sh"),
    "rubocop" => Placed.new(:ruby_bundler, "lint.sh"),
    "ruff" => Placed.new(:python, "lint.sh"),
    "rustc" => Placed.new(:rust_cargo, "build.sh"),
    "structlog" => Placed.new(:python, nil),
    "swift-test" => Placed.new(:swift, "fast.sh"),
    "tsc" => Placed.new(:node_npm, nil),
    "unittest" => Placed.new(:python, nil),
    "vitest" => Placed.new(:node_npm, "fast.sh")
  }.freeze

  FORMATS = %w[ecs logstash shellcheck].freeze

  def self.named = STACKS.keys + FORMATS
end
