# frozen_string_literal: true

require_relative "../test_helper"

# A helper in a test named after one of Minitest's own methods (run, name,
# failures, ...) replaces it, and the parallel executor then fails the whole
# file with "result not reported", hiding which test it was (CLAUDE.md, Gotchas).
class TestTestHelperNames < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  HOOKS = %w[setup teardown before_setup after_setup before_teardown after_teardown].freeze

  def test_no_test_defines_a_method_minitest_has
    clashes = Dir.glob("{test,contract}/**/test_*.rb", base: ROOT).flat_map { |path| clashes_in(path) }

    assert_empty clashes
  end

  private

  def clashes_in(path)
    File.read(File.join(ROOT, path)).scan(/^\s*def (?:self\.)?(\w+[?!=]?)/).flatten
        .select { |method| minitest_methods.include?(method) }.map { |method| "#{path}: #{method}" }
  end

  def minitest_methods
    own = Minitest::Test.instance_methods + Minitest::Test.private_instance_methods
    plain = Object.instance_methods + Object.private_instance_methods
    (own - plain).map(&:to_s).reject { |method| method.start_with?("assert", "refute", "test_", "_") } - HOOKS
  end
end
