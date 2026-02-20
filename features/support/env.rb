# frozen_string_literal: true

# Cucumber support file for fun-ci Admin TUI acceptance tests
#
# Sets up an acceptance test client that hides TUI interaction
# details behind a clean, intent-revealing API.

require "minitest"
require "tmpdir"
require "stringio"
require "time"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "fun_ci/admin_tui"
require "fun_ci/ansi"

# Acceptance test client for the Admin TUI.
# Provides a high-level API that hides database setup,
# rendering, and ANSI parsing from the step definitions.
class TuiTestClient
  attr_reader :output, :tui, :plain_output

  def initialize
    @dir = Dir.mktmpdir
    db_path = File.join(@dir, "test.sqlite3")
    @db = FunCi::Database.connection(db_path)
    FunCi::Database.migrate!(@db)
    @output = StringIO.new
    @tui = nil
    @current_run_id = nil
    @current_stages = {}
    @now = Time.now
  end

  def cleanup
    @db.close
    FileUtils.remove_entry @dir
  end

  # --- Fixture creation ---

  def create_pipeline_run(commit:, branch:, status: "completed", minutes_ago: 0)
    @now = Time.now
    run_id = FunCi::PipelineRun.create(@db, commit_hash: commit, branch: branch)

    if status != "scheduled"
      FunCi::PipelineRun.update_status(@db, run_id, "running")
    end

    case status
    when "completed"
      FunCi::PipelineRun.update_status(@db, run_id, "completed")
    when "failed"
      FunCi::PipelineRun.update_status(@db, run_id, "failed")
    when "timed_out"
      FunCi::PipelineRun.update_status(@db, run_id, "timed_out")
    when "cancelled"
      FunCi::PipelineRun.update_status(@db, run_id, "cancelled")
    end

    if minutes_ago > 0
      past_time = (@now - minutes_ago * 60).utc.iso8601
      @db.execute("UPDATE pipeline_runs SET updated_at = ? WHERE id = ?", [past_time, run_id])
    end

    @current_run_id = run_id
    @current_stages = {}
    run_id
  end

  def add_stage(stage:, status: "completed", duration: nil)
    job_id = FunCi::StageJob.create(@db, pipeline_run_id: @current_run_id, stage: stage)

    if status != "scheduled"
      FunCi::StageJob.update_status(@db, job_id, "running")
    end

    case status
    when "completed"
      FunCi::StageJob.update_status(@db, job_id, "completed")
      if duration
        started = @now - duration
        @db.execute("UPDATE stage_jobs SET started_at = ?, completed_at = ? WHERE id = ?",
          [started.utc.iso8601(3), @now.utc.iso8601(3), job_id])
      end
    when "failed"
      FunCi::StageJob.update_status(@db, job_id, "failed")
      if duration
        started = @now - duration
        @db.execute("UPDATE stage_jobs SET started_at = ?, completed_at = ? WHERE id = ?",
          [started.utc.iso8601(3), @now.utc.iso8601(3), job_id])
      end
    when "timed_out"
      FunCi::StageJob.update_status(@db, job_id, "timed_out")
      if duration
        started = @now - duration
        @db.execute("UPDATE stage_jobs SET started_at = ?, completed_at = ? WHERE id = ?",
          [started.utc.iso8601(3), @now.utc.iso8601(3), job_id])
      end
    when "running"
      # Leave as running with a started_at
      if duration
        started = @now - duration
        @db.execute("UPDATE stage_jobs SET started_at = ? WHERE id = ?",
          [started.utc.iso8601(3), job_id])
      end
    end

    @current_stages[stage] = job_id
    job_id
  end

  def create_full_passed_run(commit:, branch:, build_time: 0.3, fast_time: 1.8, slow_time: 47, minutes_ago: 0)
    create_pipeline_run(commit: commit, branch: branch, status: "completed", minutes_ago: minutes_ago)
    add_stage(stage: "build", status: "completed", duration: build_time)
    add_stage(stage: "fast", status: "completed", duration: fast_time)
    add_stage(stage: "slow", status: "completed", duration: slow_time)
  end

  def complete_running_pipeline
    # Find the running pipeline and mark it as completed
    rows = @db.execute("SELECT id FROM pipeline_runs WHERE status = 'running' ORDER BY id DESC LIMIT 1")
    return if rows.empty?
    run_id = rows[0][0]
    FunCi::PipelineRun.update_status(@db, run_id, "completed")

    # Complete all running stage jobs
    stage_rows = @db.execute("SELECT id FROM stage_jobs WHERE pipeline_run_id = ? AND status = 'running'", [run_id])
    stage_rows.each do |row|
      FunCi::StageJob.update_status(@db, row[0], "completed")
    end

    # Complete scheduled stage jobs too
    scheduled_rows = @db.execute("SELECT id FROM stage_jobs WHERE pipeline_run_id = ? AND status = 'scheduled'", [run_id])
    scheduled_rows.each do |row|
      FunCi::StageJob.update_status(@db, row[0], "running")
      FunCi::StageJob.update_status(@db, row[0], "completed")
    end
  end

  # --- TUI interaction ---

  def open_tui
    if @tui
      # Re-render existing TUI (preserves cursor state)
      rerender
    else
      @output = StringIO.new
      @tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new(""))
      @tui.render_once
      @plain_output = FunCi::Ansi.strip(@output.string)
    end
  end

  def open_tui_at_width(width)
    @output = StringIO.new
    @tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new(""), width: width)
    @tui.render_once
    @plain_output = FunCi::Ansi.strip(@output.string)
  end

  def simulate_resize(new_width)
    @tui.resize(new_width)
    rerender
  end

  def open_tui_with_width_provider(initial_width)
    @current_width = initial_width
    @output = StringIO.new
    @tui = FunCi::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: initial_width, width_provider: -> { @current_width }
    )
    @tui.render_once
    @plain_output = FunCi::Ansi.strip(@output.string)
  end

  def set_width_provider_value(new_width)
    @current_width = new_width
  end

  def header_line
    @plain_output.lines.first&.chomp
  end

  def stop_run_loop
    # No-op unless a run loop thread is active
  end

  def rerender
    @output.truncate(0)
    @output.rewind
    @tui.render_once
    @plain_output = FunCi::Ansi.strip(@output.string)
  end

  def raw_output
    @output.string
  end

  def board_lines
    @plain_output.lines.map(&:chomp)
  end
end

module MinitestWorld
  include Minitest::Assertions
  attr_accessor :assertions

  def initialize
    self.assertions = 0
    super
  end
end

World(MinitestWorld)

Before do
  @client = TuiTestClient.new
end

After do
  @client.stop_run_loop
  @client.cleanup
end
