# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/extract_options"

# The arguments of `fun-ci extract` (acceptance-tests.md, AT-10.16).
class TestExtractOptions < Minitest::Test
  OPTIONS = FunCi::Evidence::ExtractOptions

  def test_should_take_a_failed_exit_of_1_by_default
    assert_equal 1, OPTIONS.parse(%w[fast --output f]).exit_status
  end

  def test_should_take_the_exit_status_given
    assert_equal 3, OPTIONS.parse(%w[fast --output f --exit 3]).exit_status
  end

  def test_should_refuse_a_run_without_an_output
    assert_equal "--output FILE names the saved output to read", refusal(%w[fast])
  end

  def test_should_refuse_more_than_one_stage
    assert_equal "name one stage of lint, build, fast, slow, not fast slow", refusal(%w[fast slow --output f])
  end

  private

  def refusal(args) = assert_raises(OPTIONS::Invalid) { OPTIONS.parse(args) }.message
end
