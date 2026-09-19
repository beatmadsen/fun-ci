# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "cucumber/rake/task"

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

task default: %i[test cucumber]
