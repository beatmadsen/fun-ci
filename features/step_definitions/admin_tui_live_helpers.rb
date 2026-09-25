# frozen_string_literal: true

require_relative "admin_tui_step_helpers"

# Helpers for reading the live parts of a running row: spinners and stage colours.
module AdminTuiLiveHelpers
  ACTIVE_STAGE_GLYPH = /(?:Build|Fast|Slow) (#{AdminTuiStepHelpers::BRAILLE})/

  def spinner_glyph_after_refresh(stage)
    @client.refresh
    running = run_rows.find { |row| row.include?("RUNNING") } || flunk("Should show a RUNNING row")
    stage_segment(running, stage)[AdminTuiStepHelpers::BRAILLE]
  end

  def running_row_glyphs
    run_rows.grep(/RUNNING/).filter_map { |row| row[ACTIVE_STAGE_GLYPH, 1] }
  end

  def assert_stage_green_without_spinner(stage, text)
    row = raw_row("RUNNING")
    assert row, "Should show a RUNNING row"
    assert_includes row, "\e[32m#{text}\e[0m", "#{stage} should show '#{text}' in green"
    refute_match(AdminTuiStepHelpers::BRAILLE, stage_segment(FunCi::Tui::Ansi.strip(row), stage),
                 "#{stage} should not show a spinner")
  end
end

World(AdminTuiLiveHelpers)
