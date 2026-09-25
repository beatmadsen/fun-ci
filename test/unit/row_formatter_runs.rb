# frozen_string_literal: true

require "fun_ci/tui/row_formatter"
require "fun_ci/tui/ansi"

module RowFormatterRuns
  def formatted(run, **)
    FunCi::Tui::RowFormatter.format(run, **)
  end

  def plain_formatted(run, **)
    FunCi::Tui::Ansi.strip(formatted(run, **))
  end

  # stages: [[stage, status, duration], ...]
  def make_run(commit_hash, branch, status, stages = [])
    { commit_hash: commit_hash, branch: branch, status: status, updated_at: Time.now.utc.iso8601,
      stages: stages.map { |stage, state, duration| { stage: stage, status: state, duration: duration } } }
  end
end
