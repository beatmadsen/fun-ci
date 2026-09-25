# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "cucumber/rake/task"
require "rubocop/rake_task"
require "etc"

# `test` is the gate's lane; the others are quicker subsets of it.
# test/policy/test_gate_lanes.rb holds them to that.
TEST_LANES = {
  "test" => "test/**/test_*.rb",
  "unit" => "test/unit/**/test_*.rb",
  "integration" => "test/integration/**/test_*.rb",
  "acceptance" => "test/acceptance/**/test_*.rb",
  "policy" => "test/policy/**/test_*.rb"
}.freeze

TEST_LANES.each do |lane, pattern|
  Rake::TestTask.new(lane) do |t|
    t.libs.push("test", "lib")
    t.test_files = FileList[pattern]
  end
end

Cucumber::Rake::Task.new(:cucumber)

def capture_golden_corpus
  require_relative "contract/capture/golden_corpus"
  corpus = FunCi::Contract::GoldenCorpus.new(root: File.expand_path("contract", __dir__))
  corpus.scenario_names.each { |name| corpus.write(name, corpus.capture(name)) }
end

# Kept out of `rake test`: it needs the binary cargo builds first.
def drive_renderer_binary
  sh "cargo", "build", "--manifest-path", RENDERER_MANIFEST
  binary = File.expand_path("renderer/target/debug/fun-ci-renderer", __dir__)
  sh({ "FUN_CI_RENDERER" => binary }, FileUtils::RUBY, "-Itest", "-Ilib", "contract/binary/test_renderer_binary.rb")
end

namespace :contract do
  desc "Write the Ruby renderer's frames for every contract/scenarios/*.jsonl to contract/golden/"
  task(:capture) { capture_golden_corpus }

  desc "Drive the real renderer binary on a pseudo-terminal through the happy-7 contract fixture"
  task(:binary) { drive_renderer_binary }
end

RuboCop::RakeTask.new

require_relative "test/support/mutation_scope"
MUTATED = MutationScope.sources

# Mutineer runs a mutant's covering tests serially and kills a run that passes
# ten seconds. End-to-end tests run whole pipelines with real git and freshly
# written stage scripts, which macOS scans on first exec (130-250 ms each), so
# the Trigger mutants they cover overran that cap; they are left out.
MUTATION_TESTS = FileList[TEST_LANES.fetch("test")].exclude("test/test_helper.rb",
                                                            "test/integration/process/end_to_end/**/*")

def mutineer(*extra)
  tests = MUTATION_TESTS.flat_map { |file| ["--test", file] }
  command = ["bundle", "exec", "mutineer", "run", *MUTATED, *tests, "--strategy", "redefine", *extra]
  sh({ "MUTATION_TESTING" => "1", "RUBYOPT" => "-Ilib -Itest" }, *command, verbose: false)
end

desc "Mutation testing over lib (Ruby >= 3.4); fails below the threshold in .mutineer.yml"
task(:mutation) { mutineer }

namespace :mutation do
  desc "Mutation testing over lines changed since HEAD; a prompt to look, not a verdict"
  task(:changed) { mutineer("--since", "HEAD") }
end

RENDERER_MANIFEST = File.expand_path("renderer/Cargo.toml", __dir__)

namespace :rust do
  desc "Run the Rust renderer's tests"
  task(:test) { sh "cargo", "test", "--manifest-path", RENDERER_MANIFEST }

  desc "Lint the Rust renderer with clippy (pedantic, warnings are errors)"
  task(:clippy) { sh "cargo", "clippy", "--manifest-path", RENDERER_MANIFEST, "--all-targets", "--", "-D", "warnings" }
end

RUST_MUTATION_THRESHOLD = 90

def rust_mutation(threshold)
  require_relative "renderer/tools/mutation_score"
  status = run_cargo_mutants
  abort "cargo mutants measured nothing (exit #{status.inspect})" unless FunCi::Mutation.completed?(status)
  score = FunCi::Mutation::Score.load(File.expand_path("renderer/mutants.out/outcomes.json", __dir__))
  puts score.summary
  abort "Rust mutation score is under #{threshold}%" unless score.passes?(threshold)
end

# Tests read the golden corpus through FUN_CI_CONTRACT, because cargo-mutants
# builds a copy of renderer/ that has no ../contract next to it. The suite takes
# seconds; the fixed timeout is for mutants that make a test wait forever (one
# that stops SIGTERM being handled leaves the pty test waiting for an exit).
def run_cargo_mutants
  renderer = File.expand_path("renderer", __dir__)
  env = { "FUN_CI_CONTRACT" => File.expand_path("contract", __dir__) }
  jobs = [Etc.nprocessors / 2, 1].max.to_s
  system(env, "cargo", "mutants", "-d", renderer, "-o", renderer, "-j", jobs, "--timeout", "120")
  Process.last_status.exitstatus
end

namespace :mutation do
  desc "Mutation-test the Rust renderer with cargo-mutants; fails under 90% of viable mutants caught"
  task(:rust) { rust_mutation(RUST_MUTATION_THRESHOLD) }
end

task default: %i[test cucumber rust:test contract:binary rubocop rust:clippy]
