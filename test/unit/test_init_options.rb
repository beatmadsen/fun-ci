# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/init_options"

# What `fun-ci init` takes on its command line, and what it refuses.
class TestInitOptions < Minitest::Test
  def test_should_refuse_an_argument_that_is_no_option
    error = assert_raises(FunCi::Setup::InitOptions::Invalid) { FunCi::Setup::InitOptions.parse(%w[go]) }

    assert_equal "takes no go", error.message
  end

  # OptionParser's own --version would print and exit the process.
  def test_should_refuse_version_rather_than_let_option_parser_answer_it
    assert_raises(FunCi::Setup::InitOptions::Invalid) { FunCi::Setup::InitOptions.parse(%w[--version]) }
  end

  def test_should_take_the_stack_named
    assert_equal "go", FunCi::Setup::InitOptions.parse(%w[--stack go]).stack
  end
end
