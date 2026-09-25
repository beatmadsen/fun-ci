# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/sgr_style"

class TestSgrStyle < Minitest::Test
  STYLE = FunCi::Contract::SgrStyle
  BOLD_RED = STYLE.new(fg: 1, bold: true, dim: false)

  def test_bold_and_a_colour_set_both_attributes
    assert_equal BOLD_RED, STYLE.default.apply("1;31")
  end

  def test_a_new_colour_keeps_the_attributes_already_in_force
    assert_equal BOLD_RED.with(fg: 208), BOLD_RED.apply("38;5;208")
  end

  def test_bold_replaces_dim_because_both_set_the_intensity
    assert_equal BOLD_RED, BOLD_RED.with(bold: false, dim: true).apply("1")
  end

  def test_dim_replaces_bold_because_both_set_the_intensity
    assert_equal BOLD_RED.with(bold: false, dim: true), BOLD_RED.apply("2")
  end

  def test_bright_colours_are_indexes_eight_to_fifteen
    assert_equal 9, STYLE.default.apply("91").fg
  end

  def test_zero_resets_every_attribute
    assert_equal STYLE.default, BOLD_RED.apply("0")
  end

  def test_an_escape_without_parameters_resets_every_attribute
    assert_equal STYLE.default, BOLD_RED.apply("")
  end

  def test_an_unknown_code_is_refused
    assert_raises(KeyError) { STYLE.default.apply("5") }
  end

  def test_json_names_only_the_attributes_in_force
    assert_equal({ "fg" => 1, "bold" => true }, BOLD_RED.to_json_h)
  end
end
