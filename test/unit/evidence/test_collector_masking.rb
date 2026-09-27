# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/collector_kit"
require "json"

# Nothing a failed stage kept holds a secret masking can see (architecture.md, "Evidence of a failed stage").
class TestCollectorMasking < Minitest::Test
  include CollectorKit

  def test_should_mask_the_value_of_a_secret_in_the_stage_s_environment
    assert_equal ["token [masked:API_TOKEN]"],
                 collect("token abcdefgh123\n", environment: { "API_TOKEN" => "abcdefgh123" }).excerpts.first[:lines]
  end

  def test_should_mask_a_secret_the_size_cap_would_cut_in_two
    output = "#{"x" * 10}abcdefgh123#{"y" * 65_530}\n"
    kept = collect(output, environment: { "API_TOKEN" => "abcdefgh123" }).excerpts.first[:lines].join

    assert_equal 0, kept.scan("h123").size
  end

  def test_should_mask_what_the_project_s_own_patterns_match
    assert_equal ["id [masked]"], collect("id ACME-1234\n", settings: { "mask" => ['ACME-\d+'] }).excerpts.first[:lines]
  end

  def test_should_keep_secrets_when_the_project_turns_masking_off
    assert_equal ["token abcdefgh123"], collect("token abcdefgh123\n", settings: { "masking" => false },
                                                                       environment: { "API_TOKEN" => "abcdefgh123" })
      .excerpts.first[:lines]
  end

  def test_should_mask_the_raw_output
    assert_equal "a [masked:API_TOKEN]\n",
                 collector(environment: { "API_TOKEN" => "abcdefgh123" }).masked("a abcdefgh123\n")
  end
end
