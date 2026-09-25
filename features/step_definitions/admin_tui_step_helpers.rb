# frozen_string_literal: true

module AdminTuiStepHelpers
  BRAILLE = /[⠀-⣿]/
  COMMIT_ROW = /[a-f0-9]{7}\s+\S+/
  CURSOR_ROW = /[a-f0-9]{4,}/

  def create_run_with_stages(commit, branch, status, stages)
    @client.create_pipeline_run(commit: commit, branch: branch, status: status)
    stages.each do |stage, (stage_status, duration)|
      @client.add_stage(stage: stage.to_s, status: stage_status, duration: duration)
    end
  end

  # Build done, fast suite running, slow suite waiting.
  def create_running_run(commit, branch, fast_seconds:, build_seconds: 0.2)
    create_run_with_stages(commit, branch, "running",
                           build: ["completed", build_seconds], fast: ["running", fast_seconds], slow: ["scheduled"])
  end

  def create_passed_runs(count, prefix, digits: 3)
    count.times { |i| @client.create_full_passed_run(commit: "#{prefix}#{i.to_s.rjust(digits, "0")}", branch: "main") }
  end

  def open_tui_and_press(*keys)
    @client.open_tui
    keys.each { |key| @client.tui.handle_key(key) }
  end

  def press_and_rerender(key)
    @client.tui.handle_key(key)
    @client.rerender
  end

  def board_lines_matching(pattern)
    @client.board_lines.grep(pattern)
  end

  def commit_rows
    board_lines_matching(COMMIT_ROW)
  end

  def cursor_rows
    board_lines_matching(CURSOR_ROW)
  end

  def footer_lines
    @client.board_lines.select { |l| l.include?("quit") }
  end

  def escaped(text)
    Regexp.escape(text)
  end
end

World(AdminTuiStepHelpers)
