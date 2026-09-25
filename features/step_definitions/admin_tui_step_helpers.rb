# frozen_string_literal: true

module AdminTuiStepHelpers
  BRAILLE = /[⠀-⣿]/
  COMMIT_ROW = /[a-f0-9]{7}\s+\S+/
  RUN_ROW = /PASSED|FAILED|RUNNING|TIMED OUT|CANCELLED|Scheduled\.\.\./
  CURSOR = /\A> /
  PROMPT = /Cancel.*\?/

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
    keys.each { |key| @client.press(key) }
  end

  def board_lines_matching(pattern)
    @client.board_lines.grep(pattern)
  end

  def commit_rows
    board_lines_matching(COMMIT_ROW)
  end

  def run_rows
    board_lines_matching(RUN_ROW)
  end

  def raw_row(text)
    @client.raw_lines.find { |line| FunCi::Tui::Ansi.strip(line).include?(text) }
  end

  def assert_cursor_on(index)
    rows = run_rows
    assert_operator rows.length, :>, index, "Board should have a row #{index + 1}: #{rows.inspect}"
    assert_equal [index], rows.each_index.select { |i| rows[i].match?(CURSOR) }, "Only row #{index + 1} is selected"
  end

  # The text of one stage on a row, e.g. "Build 0.2s" out of "... Build 0.2s  Fast 2.4s ...".
  def stage_segment(row, stage)
    row[/#{stage} .*?(?=  )/] || flunk("Row should show a #{stage} stage: #{row.inspect}")
  end

  # The commit a board row starts with, past the cursor marker if the row has it.
  def row_commit(row)
    row.delete_prefix("> ")[/\S+/]
  end

  def sgr_codes(raw_line)
    raw_line.scan(/\e\[([0-9;]*)m/).flatten.uniq.sort
  end

  def footer_lines
    @client.board_lines.select { |l| l.include?("quit") }
  end

  def escaped(text)
    Regexp.escape(text)
  end
end

World(AdminTuiStepHelpers)
