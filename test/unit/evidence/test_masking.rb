# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/masking"

# Secrets are masked before anything is kept (architecture.md, "Evidence of a failed stage").
class TestMasking < Minitest::Test
  MASKING = FunCi::Evidence::Masking

  def test_should_name_the_variable_whose_value_it_masks
    assert_equal "push [masked:DEPLOY_TOKEN]", mask("push s3cr3t-value-123", "DEPLOY_TOKEN" => "s3cr3t-value-123")
  end

  def test_should_mask_each_kind_of_secret_name
    environment = { "A_TOKEN" => "value-one", "A_SECRET" => "value-two", "A_PASSWORD" => "value-three",
                    "A_PASSWD" => "value-four", "A_API_KEY" => "value-five", "A_PRIVATE_KEY" => "value-six",
                    "A_CREDENTIAL" => "value-seven" }

    assert_equal "[masked:A_TOKEN] [masked:A_SECRET] [masked:A_PASSWORD] [masked:A_PASSWD] [masked:A_API_KEY] " \
                 "[masked:A_PRIVATE_KEY] [masked:A_CREDENTIAL]",
                 mask("value-one value-two value-three value-four value-five value-six value-seven", environment)
  end

  def test_should_leave_the_value_of_a_variable_whose_name_is_not_secret
    assert_equal "home is /home/developer", mask("home is /home/developer", "HOME" => "/home/developer")
  end

  def test_should_leave_a_secret_shorter_than_8_characters
    assert_equal "pin 1234567", mask("pin 1234567", "PIN_SECRET" => "1234567")
  end

  def test_should_mask_a_secret_of_8_characters
    assert_equal "pin [masked:PIN_SECRET]", mask("pin 12345678", "PIN_SECRET" => "12345678")
  end

  def test_should_mask_a_longer_secret_that_contains_a_shorter_one_whole
    environment = { "SHORT_TOKEN" => "abcdefgh", "LONG_TOKEN" => "abcdefgh-ijkl" }

    assert_equal "[masked:LONG_TOKEN]", mask("abcdefgh-ijkl", environment)
  end

  def test_should_mask_a_github_token
    assert_equal "gh [masked]", mask("gh ghp_#{"a" * 36}")
  end

  def test_should_mask_an_aws_access_key_id
    assert_equal "key [masked]", mask("key AKIAIOSFODNN7EXAMPLE")
  end

  def test_should_mask_a_slack_token
    assert_equal "slack [masked]", mask("slack xoxb-1234567890-abcdefghij")
  end

  def test_should_mask_an_authorization_header_s_value
    assert_equal "Authorization: [masked]", mask("Authorization: Bearer abc.def.ghi")
  end

  def test_should_mask_a_pem_private_key_block
    pem = "-----BEGIN RSA PRIVATE KEY-----\nMIIEow\nIBAAK\n-----END RSA PRIVATE KEY-----"

    assert_equal "before\n[masked]\nafter", mask("before\n#{pem}\nafter")
  end

  def test_should_mask_what_a_project_s_own_pattern_matches
    masking = MASKING.new({}, patterns: [Regexp.new("ACME-[0-9a-f]{8}")])

    assert_equal "id [masked]", masking.mask("id ACME-0123abcd")
  end

  def test_should_mask_text_whose_bytes_are_not_all_unicode
    text = "\xFF abcdefgh123".dup.force_encoding(Encoding::UTF_8)

    assert_equal "\uFFFD [masked:API_TOKEN]", mask(text, "API_TOKEN" => "abcdefgh123")
  end

  private

  def mask(text, environment = {}) = MASKING.new(environment).mask(text)
end
