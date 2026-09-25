# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

# With many pipeline runs the TUI shows one page at a time; scrolling past the
# bottom loads the next page.
class TestTuiPagination < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  PAGE_SIZE = 5

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_only_first_page_initially
    create_numbered_runs(15)
    make_tui.render_once
    rows = visible_commit_rows
    assert_equal PAGE_SIZE, rows, "Should show only #{PAGE_SIZE} rows initially, got #{rows}"
  end

  def test_should_load_more_when_scrolling_past_bottom
    create_numbered_runs(15)
    tui = make_tui
    PAGE_SIZE.times { tui.handle_key("j") }
    @output.string = +""
    tui.render_once
    assert_operator visible_commit_rows, :>, PAGE_SIZE,
                    "Should show more than #{PAGE_SIZE} rows after scrolling past bottom"
  end

  private

  def make_tui
    FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, page_size: PAGE_SIZE
    )
  end

  def visible_commit_rows
    FunCi::Tui::Ansi.strip(@output.string).lines.grep(/run\d+/).size
  end

  def create_numbered_runs(count)
    count.times { |i| create_completed_run("run#{format("%02d", i + 1)}", "main") }
  end
end
