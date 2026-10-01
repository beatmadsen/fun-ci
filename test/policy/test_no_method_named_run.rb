# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/call_scanner"
require "prism"

# No test code defines a method named `run` or calls `run` without a
# receiver. Minitest runs each test through its own `run`: a helper of that
# name replaces it, and a bare call left behind by a rename runs the test
# again from inside itself, without end, in every worker at once, which once
# took the machine down (CLAUDE.md, Invariants). The two guards that wrap
# Minitest's own `run` are the exception. MinitestGuards refuses the same at run
# time, in a lane this scan isn't part of.
class TestNoMethodNamedRun < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  TEST_CODE = "{test,contract}/**/*.rb"
  WRAPS_MINITEST_RUN = %w[test/support/minitest_guards.rb test/support/stray_stderr_guard.rb].freeze
  # Makes the mistake on purpose, in a scratch test, to watch MinitestGuards refuse it.
  PROVOKES_IT = %w[test/unit/test_minitest_guards.rb].freeze
  BARE_RUN = CallScanner::Rules.new(bare: %i[run], on_receiver: {}, any_receiver: [], backticks: false)

  def test_no_test_code_defines_a_method_named_run
    assert_empty(sources.select { |path| defines_run?(File.read(File.join(ROOT, path))) })
  end

  def test_no_test_code_calls_run_without_a_receiver
    assert_empty(sources.flat_map { |path| CallScanner.new(File.read(File.join(ROOT, path)), path, BARE_RUN).offences })
  end

  def test_the_scan_finds_a_method_named_run
    assert defines_run?("module Kit\n  def self.run = nil\nend\n")
  end

  def test_the_scan_reads_the_tests_and_the_contract_s_ruby
    assert_equal %w[contract test], sources.map { |path| path.split("/").first }.uniq.sort
  end

  def test_the_runtime_guard_is_installed
    assert_includes Minitest::Test.ancestors, MinitestGuards::Reentry
  end

  private

  def sources = Dir.glob(TEST_CODE, base: ROOT) - WRAPS_MINITEST_RUN - PROVOKES_IT

  def defines_run?(source) = defs(Prism.parse(source).value).include?(:run)

  def defs(node)
    own = node.is_a?(Prism::DefNode) ? [node.name] : []
    own + node.compact_child_nodes.flat_map { |child| defs(child) }
  end
end
