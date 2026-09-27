# frozen_string_literal: true

# Whether what a preset picked out of two runs of its tool is the same, each
# given as excerpts of lines. What differs between runs of one release is
# left out: numbers (durations, pids, times), addresses, a duration Bun
# prints only for a test slow enough, and the order the failures came in,
# which tools such as ExUnit shuffle on each run.
module ExcerptComparison
  RUN_TO_RUN = /0x\h+|\d+/
  SLOW_TEST = / \[[\d.]+m?s\]$/

  def self.same?(before, after) = normalised(before) == normalised(after)

  def self.normalised(excerpts) = excerpts.map { |lines| lines.map { |line| line_of_any_run(line) } }.sort

  def self.line_of_any_run(line) = line.sub(SLOW_TEST, "").gsub(RUN_TO_RUN, "#")
end
