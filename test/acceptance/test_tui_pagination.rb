# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/admin_tui"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "fun_ci/ansi"
require "tmpdir"
require "stringio"

# Acceptance test for Feature 2: TUI pagination.
#
# When the database contains many pipeline runs, the TUI should show
# only a page at a time. Scrolling to the bottom loads the next page.
#
# ATDD outer loop: this test stays RED until pagination is implemented.

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
    # Given 15 pipeline runs and a page size of 5
    create_numbered_runs(15)
    tui = make_tui

    # When the TUI renders
    tui.render_once

    # Then only 5 commit rows should be visible
    visible = FunCi::Ansi.strip(@output.string)
    commit_rows = visible.lines.select { |l| l.match?(/run\d+/) }
    assert_equal PAGE_SIZE, commit_rows.size,
      "Should show only #{PAGE_SIZE} rows initially, got #{commit_rows.size}"
  end

  def test_should_load_more_when_scrolling_past_bottom
    # Given 15 pipeline runs and a page size of 5
    create_numbered_runs(15)
    tui = make_tui

    # When user scrolls to the bottom and then presses j once more
    PAGE_SIZE.times { tui.handle_key("j") }
    @output.truncate(0)
    @output.rewind
    tui.render_once

    # Then more rows should be visible (second page loaded)
    visible = FunCi::Ansi.strip(@output.string)
    commit_rows = visible.lines.select { |l| l.match?(/run\d+/) }
    assert_operator commit_rows.size, :>, PAGE_SIZE,
      "Should show more than #{PAGE_SIZE} rows after scrolling past bottom"
  end

  private

  def make_tui
    FunCi::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, page_size: PAGE_SIZE
    )
  end

  def create_numbered_runs(count)
    count.times do |i|
      commit = "run#{format("%02d", i + 1)}"
      create_completed_run(commit, "main")
    end
  end
end
