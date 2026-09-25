# frozen_string_literal: true

require_relative "../test_helper"
require "open3"
require "tmpdir"

# A green run writes nothing to stderr, so anything there is an error nobody
# asserted on: a dying thread, a forked child's exception. It fails the run.
class TestStrayStderrGuard < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_a_run_that_writes_to_stderr_fails
    output, status = run_suite(%(Thread.new { warn "stray boom" }.join))

    refute status.success?
    assert_match(/stray boom/, output)
  end

  def test_a_run_that_keeps_stderr_clean_passes
    _, status = run_suite("nil")

    assert_predicate status, :success?
  end

  private

  def run_suite(body)
    Dir.mktmpdir("stderr-guard") do |dir|
      path = File.join(dir, "test_probe.rb")
      File.write(path, probe(body))
      Open3.capture2e("ruby", "-I#{ROOT}/test", "-I#{ROOT}/lib", path, chdir: dir)
    end
  end

  def probe(body)
    <<~RUBY
      require "test_helper"
      class TestProbe < Minitest::Test
        def test_probe = #{body}
      end
    RUBY
  end
end
