# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"
require "tmpdir"

# A green run writes nothing to stderr, so anything there is an error nobody
# asserted on: a dying thread, a forked child's exception. It fails the run.
class TestStrayStderrGuard < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def test_a_run_that_writes_to_stderr_fails
    refute_predicate run_suite(%(Thread.new { warn "stray boom" }.join)).last, :success?
  end

  def test_a_run_that_writes_to_stderr_shows_what_was_written
    assert_match(/stray boom/, run_suite(%(Thread.new { warn "stray boom" }.join)).first)
  end

  def test_a_run_that_keeps_stderr_clean_passes
    assert_predicate run_suite("nil").last, :success?
  end

  def test_a_test_file_that_fails_to_load_says_why
    output, = run_suite("nil", preamble: 'require "no-such-library"')

    assert_match(/cannot load such file -- no-such-library/, output)
  end

  private

  def run_suite(body, preamble: "")
    Dir.mktmpdir("stderr-guard") do |dir|
      path = File.join(dir, "test_probe.rb")
      File.write(path, probe(body, preamble))
      Open3.capture2e("ruby", "-I#{ROOT}/test", "-I#{ROOT}/lib", path, chdir: dir)
    end
  end

  def probe(body, preamble)
    <<~RUBY
      require "test_helper"
      #{preamble}
      class TestProbe < Minitest::Test
        def test_probe = #{body}
      end
    RUBY
  end
end
