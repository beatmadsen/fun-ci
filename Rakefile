# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "cucumber/rake/task"
require "rubocop/rake_task"

# `test` is the gate's lane; the others are quicker subsets of it.
# test/unit/test_gate_lanes.rb holds them to that.
TEST_LANES = {
  "test" => "test/**/test_*.rb",
  "unit" => "test/unit/**/test_*.rb",
  "integration" => "test/integration/**/test_*.rb",
  "acceptance" => "test/acceptance/**/test_*.rb"
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

namespace :contract do
  desc "Write the Ruby renderer's frames for every contract/scenarios/*.jsonl to contract/golden/"
  task(:capture) { capture_golden_corpus }
end

RuboCop::RakeTask.new

# tui/ and animations/ are left out: §5 of the 2.0 plan deletes them once the
# Rust renderer takes over, and killing their mutants would be spent effort.
MUTATED = FileList["lib/**/*.rb"].exclude("lib/fun_ci/{tui,animations}/**/*.rb")

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

task default: %i[test cucumber rubocop]
