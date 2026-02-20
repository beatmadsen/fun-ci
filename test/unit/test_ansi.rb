# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/ansi"

class TestAnsi < Minitest::Test
  def test_should_wrap_text_in_green
    result = FunCi::Ansi.green("hello")
    assert_match(/hello/, result)
    assert_match(/\e\[32m/, result, "Should contain green ANSI code")
    assert_match(/\e\[0m/, result, "Should contain reset code")
  end

  def test_should_wrap_text_in_bold_green
    result = FunCi::Ansi.bold_green("PASSED")
    assert_match(/PASSED/, result)
    assert_match(/\e\[1;32m/, result, "Should contain bold green ANSI code")
  end

  def test_should_wrap_text_in_bold_red
    result = FunCi::Ansi.bold_red("FAILED")
    assert_match(/FAILED/, result)
    assert_match(/\e\[1;31m/, result, "Should contain bold red ANSI code")
  end

  def test_should_wrap_text_in_bold_yellow
    result = FunCi::Ansi.bold_yellow("TIMED OUT")
    assert_match(/TIMED OUT/, result)
    assert_match(/\e\[1;33m/, result, "Should contain bold yellow ANSI code")
  end

  def test_should_wrap_text_in_cyan
    result = FunCi::Ansi.cyan("Fast")
    assert_match(/Fast/, result)
    assert_match(/\e\[36m/, result, "Should contain cyan ANSI code")
  end

  def test_should_wrap_text_in_bold_cyan
    result = FunCi::Ansi.bold_cyan("RUNNING")
    assert_match(/RUNNING/, result)
    assert_match(/\e\[1;36m/, result, "Should contain bold cyan ANSI code")
  end

  def test_should_wrap_text_in_dim
    result = FunCi::Ansi.dim("2m ago")
    assert_match(/2m ago/, result)
    assert_match(/\e\[2m/, result, "Should contain dim ANSI code")
  end

  def test_should_render_charcoal_background
    result = FunCi::Ansi.bg_charcoal("fun-ci")
    assert_match(/fun-ci/, result)
    assert_match(/\e\[48;5;236m/, result, "Should contain 256-color charcoal bg")
  end

  def test_should_strip_all_ansi_codes
    colored = FunCi::Ansi.bold_green("PASSED")
    result = FunCi::Ansi.strip(colored)
    assert_equal "PASSED", result, "Should remove all ANSI escape sequences"
  end

  def test_should_strip_cursor_and_screen_control_sequences
    # Given text with CSI control sequences (clear screen, cursor home)
    text = "\e[2J\e[Hfun-ci header"
    # When stripped
    result = FunCi::Ansi.strip(text)
    # Then only the plain text should remain
    assert_equal "fun-ci header", result,
      "Should strip clear-screen and cursor-home sequences"
  end
end
