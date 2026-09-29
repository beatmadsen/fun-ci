# frozen_string_literal: true

require "rake"

# This repository's Rakefile, loaded once for the policy tests that read its
# tasks and TEST_LANES. Under rake, bundler/gem_tasks is required already
# when this loads the Rakefile; run alone, requiring it evaluates the
# gemspec, whose `git ls-files` the confinement guard refuses. The gem's tasks
# are none of these tests' business, so it is taken as loaded here too.
module ProjectRakefile
  ROOT = File.expand_path("../..", __dir__)
  $LOADED_FEATURES << $LOAD_PATH.resolve_feature_path("bundler/gem_tasks").last
  APP = Rake::Application.new.tap do |app|
    Rake.application = app
    Rake.load_rakefile(File.join(ROOT, "Rakefile"))
  end

  def self.test_files(lane) = Dir.glob(TEST_LANES.fetch(lane), base: ROOT)
end
