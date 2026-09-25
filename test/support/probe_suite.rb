# frozen_string_literal: true

require "open3"
require "tmpdir"

# A one-test Minitest suite, written to a directory and run in a child Ruby
# with this repository's test_helper, so a test can watch what a guard does
# to a whole run.
module ProbeSuite
  ROOT = File.expand_path("../..", __dir__)

  # Answers [output, status]. +dir+ defaults to a fresh temporary directory;
  # +preamble+ goes between test_helper and the test class.
  def self.run(body, dir: nil, preamble: "", env: {})
    return Dir.mktmpdir("probe") { |fresh| run(body, dir: fresh, preamble: preamble, env: env) } unless dir

    File.write(File.join(dir, "test_probe.rb"), source(body, preamble))
    Open3.capture2e(env, "ruby", "-I#{ROOT}/test", "-I#{ROOT}/lib", "test_probe.rb", chdir: dir)
  end

  def self.source(body, preamble)
    <<~RUBY
      require "test_helper"
      require "sqlite3"
      require "open3"
      #{preamble}
      class TestProbe < Minitest::Test
        def test_probe
          #{body}
        end
      end
    RUBY
  end
end
