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

task default: %i[test cucumber rubocop]
