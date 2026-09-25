# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/probe_suite"
require "tmpdir"

# A connection a test leaves open is inherited by the next fork in the same
# worker, which is how an order-dependent SQLite fork-safety warning got in.
class TestSqliteConnectionGuard < Minitest::Test
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

  def run_suite(body) = ProbeSuite.run(body)
end
