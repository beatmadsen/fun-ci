# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"

# The mutation lane picks a mutant's tests by line coverage, which the boot
# file makes count one-line methods' calls (support/statement_coverage).
# Booted as mutineer boots it: coverage already running, then the boot file.
class TestMutationBootCoverage < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)
  DEADLINE = File.join(ROOT, "lib/fun_ci/evidence/deadline.rb")
  BOOT_AND_CALL = <<~RUBY.freeze
    require "coverage"
    Coverage.start(lines: true)
    require #{File.join(ROOT, "test/mutation_boot").inspect}
    Coverage.result(clear: true, stop: false)
    FunCi::Evidence::Deadline.after(-> { 0 }, 1).passed?
    print Coverage.result.fetch(#{DEADLINE.inspect}).fetch(:lines)[ARGV[0].to_i - 1]
  RUBY

  def test_should_count_a_call_of_a_one_line_method_on_its_line
    assert_equal "1", counted_on(line_of("def passed?"))
  end

  private

  def line_of(text) = File.readlines(DEADLINE).index { |line| line.include?(text) } + 1

  def counted_on(line)
    output, status = Open3.capture2e(RbConfig.ruby, "-I#{ROOT}/lib", "-I#{ROOT}/test", "-e", BOOT_AND_CALL, line.to_s)
    assert_predicate status, :success?, output
    output
  end
end
