# frozen_string_literal: true

require_relative "../test_helper"
require "open3"

# Bundler evaluates the gemspec before it installs anything, so a gemspec that
# loads the library cannot be read on a machine that does not already have the
# library's dependencies. That makes `bundle install` fail from a clean clone.
class TestGemspecLoading < Minitest::Test
  def test_loading_the_gemspec_does_not_load_the_runtime_dependencies
    assert_equal "not loaded", load_gemspec_and_report_sqlite3
  end

  private

  def load_gemspec_and_report_sqlite3
    root = File.expand_path("../..", __dir__)
    script = 'Gem::Specification.load(ARGV[0]); print defined?(SQLite3) ? "loaded" : "not loaded"'
    stdout, = Open3.capture3(
      { "RUBYOPT" => nil, "BUNDLER_SETUP" => nil, "BUNDLE_BIN_PATH" => nil },
      RbConfig.ruby, "-e", script, File.join(root, "fun_ci.gemspec")
    )
    stdout
  end
end
