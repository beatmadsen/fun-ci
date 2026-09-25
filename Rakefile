# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "cucumber/rake/task"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/**/test_*.rb"]
end

Rake::TestTask.new(:unit) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/unit/**/test_*.rb"]
end

Rake::TestTask.new(:integration) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/integration/**/test_*.rb"]
end

Rake::TestTask.new(:acceptance) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/acceptance/**/test_*.rb"]
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
