# frozen_string_literal: true

require "json"
require "open3"

# Loads a gemspec in a child Ruby, because evaluating fun_ci.gemspec runs
# `git ls-files`, and answers the parts tests look at.
module GemspecProbe
  SCRIPT = <<~RUBY
    require "json"
    spec = Gem::Specification.load(ARGV[0])
    print JSON.generate(files: spec.files, metadata: spec.metadata, executables: spec.executables)
  RUBY

  # Under `bundle exec` the child would load this repository's gem first.
  OUTSIDE_BUNDLER = %w[RUBYOPT BUNDLER_SETUP BUNDLE_BIN_PATH BUNDLE_GEMFILE].to_h { |name| [name, nil] }.freeze

  def self.load(gemspec)
    output, status = Open3.capture2e(OUTSIDE_BUNDLER, RbConfig.ruby, "-e", SCRIPT, gemspec,
                                     chdir: File.dirname(gemspec))
    raise "loading #{gemspec} failed: #{output}" unless status.success?

    JSON.parse(output)
  end
end
