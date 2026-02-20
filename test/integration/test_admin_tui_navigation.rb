# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/admin_tui"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "fun_ci/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiNavigation < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
    3.times { |i| create_completed_run("hash#{i.to_s.rjust(3, "0")}", "main") }
  end

  def teardown
    teardown_test_db
  end

  def test_should_have_no_cursor_initially
    # Given runs on the board
    tui = make_tui
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    # Then no cursor marker should be visible
    refute_match(/>/, plain, "Cursor should be invisible by default")
  end

  def test_should_show_cursor_on_first_row_after_j
    tui = make_tui
    tui.handle_key("j")
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    lines = plain.lines.select { |l| l.include?("hash") }
    assert_match(/^>/, lines[0], "First row should have cursor marker after j")
    refute_match(/^>/, lines[1], "Second row should not have cursor marker")
  end

  def test_should_move_cursor_down_on_second_j
    tui = make_tui
    tui.handle_key("j")
    tui.handle_key("j")
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    lines = plain.lines.select { |l| l.include?("hash") }
    refute_match(/^>/, lines[0], "First row should not have cursor after moving down")
    assert_match(/^>/, lines[1], "Second row should have cursor after j j")
  end

  def test_should_move_cursor_up_on_k
    tui = make_tui
    tui.handle_key("j")
    tui.handle_key("j")
    tui.handle_key("k")
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    lines = plain.lines.select { |l| l.include?("hash") }
    assert_match(/^>/, lines[0], "First row should have cursor after j j k")
  end

  def test_should_not_move_past_last_row
    tui = make_tui
    # Move to last row (index 2) then try to go further
    4.times { tui.handle_key("j") }
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    lines = plain.lines.select { |l| l.include?("hash") }
    assert_match(/^>/, lines[2], "Cursor should stay on last row")
  end

  def test_should_not_move_above_first_row
    tui = make_tui
    tui.handle_key("j")  # cursor on row 0
    tui.handle_key("k")  # try to go above
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    lines = plain.lines.select { |l| l.include?("hash") }
    assert_match(/^>/, lines[0], "Cursor should stay on first row")
  end

  private

  def make_tui
    FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new(""))
  end

end
