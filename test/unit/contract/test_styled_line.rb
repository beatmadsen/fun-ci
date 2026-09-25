# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/styled_line"

class TestStyledLine < Minitest::Test
  STYLE = FunCi::Contract::SgrStyle
  DIM_RED = STYLE.new(fg: 1, bold: false, dim: true)
  LINE = FunCi::Contract::StyledLine.parse(" \e[2;31m.\e[38;5;208m*\e[0m ")

  def test_text_is_what_the_terminal_shows
    assert_equal " .* ", LINE.text
  end

  def test_each_character_is_drawn_in_the_style_in_force
    assert_equal DIM_RED, LINE.cells[1].last
  end

  def test_styles_accumulate_across_escapes
    assert_equal DIM_RED.with(fg: 208), LINE.cells[2].last
  end

  def test_finish_is_the_style_left_in_force
    assert_equal DIM_RED, FunCi::Contract::StyledLine.parse("\e[2;31m.").finish
  end

  def test_the_mask_names_each_character_style_by_key
    assert_equal " ab ", LINE.mask(DIM_RED => "a", DIM_RED.with(fg: 208) => "b")
  end

  def test_an_escape_other_than_sgr_is_refused
    assert_raises(ArgumentError) { FunCi::Contract::StyledLine.parse("\e[2K.") }
  end
end
