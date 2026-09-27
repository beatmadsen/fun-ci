# frozen_string_literal: true

# Whether what a preset picked out of two runs of its tool is the same, each
# given as excerpts of lines. What differs between runs of one release is
# left out: numbers (durations, pids, times), addresses, and the order the
# failures came in, which tools such as ExUnit shuffle on each run.
module ExcerptComparison
  RUN_TO_RUN = /0x\h+|\d+/

  def self.same?(before, after) = normalised(before) == normalised(after)

  def self.normalised(excerpts) = excerpts.map { |lines| lines.map { |line| line.gsub(RUN_TO_RUN, "#") } }.sort
end
