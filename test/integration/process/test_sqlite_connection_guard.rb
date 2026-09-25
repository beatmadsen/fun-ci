# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"
require "tmpdir"

# A connection a test leaves open is inherited by the next fork in the same
# worker, which is how an order-dependent SQLite fork-safety warning got in.
class TestSqliteConnectionGuard < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def test_a_test_that_leaves_a_connection_open_fails_and_is_named
    output, status = run_suite(%(SQLite3::Database.new(":memory:")))

    refute status.success?
    assert_match(/TestProbe#test_probe left 1 SQLite connection open/, output)
  end

  def test_a_test_that_closes_its_connections_passes
    _, status = run_suite(%(SQLite3::Database.new(":memory:").close))

    assert_predicate status, :success?
  end

  private

  def run_suite(body)
    Dir.mktmpdir("sqlite-guard") do |dir|
      path = File.join(dir, "test_probe.rb")
      File.write(path, probe(body))
      Open3.capture2e("ruby", "-I#{ROOT}/test", "-I#{ROOT}/lib", path, chdir: dir)
    end
  end

  def probe(body)
    <<~RUBY
      require "test_helper"
      require "sqlite3"
      class TestProbe < Minitest::Test
        def test_probe = #{body}
      end
    RUBY
  end
end
