# frozen_string_literal: true

require "forwardable"
require "tmpdir"
require_relative "tui_fixtures"
require_relative "tui_driver"

# Acceptance test client for the Admin TUI.
# Provides a high-level API that hides database setup,
# rendering, and ANSI parsing from the step definitions.
class TuiTestClient
  extend Forwardable

  def_delegators :@fixtures, :create_pipeline_run, :add_stage, :create_full_passed_run, :complete_running_pipeline,
                 :let_time_pass, :commits_newest_first, :run_status
  def_delegators :@driver, :tui, :plain_output, :previous_plain_output, :raw_output, :raw_lines,
                 :header_line, :board_lines
  def_delegators :@driver, :open_tui, :open_tui_at_width, :open_tui_with_width_provider,
                 :simulate_resize, :refresh, :press, :terminal_height=
  def_delegators :@driver, :exited?, :refresh_interval, :terminal_modes
  def_delegator :@driver, :provide_width, :set_width_provider_value
  def_delegator :@driver, :refresh, :rerender
  def_delegator :@driver, :stop, :stop_run_loop

  def initialize
    @dir = Dir.mktmpdir
    @db = FunCi::Persistence::Database.connection(File.join(@dir, "test.sqlite3"))
    FunCi::Persistence::Database.migrate!(@db)
    @fixtures = TuiFixtures.new(@db)
    @driver = TuiDriver.new(@db)
  end

  def cleanup
    @db.close
    FileUtils.remove_entry @dir
  end
end
