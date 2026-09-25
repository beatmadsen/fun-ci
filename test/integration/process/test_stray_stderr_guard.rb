# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/probe_suite"
require "tmpdir"

# A green run writes nothing to stderr, so anything there is an error nobody
# asserted on: a dying thread, a forked child's exception. It fails the run.
class TestStrayStderrGuard < Minitest::Test
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

  def run_suite(body, preamble: "") = ProbeSuite.run(body, preamble: preamble)
end
