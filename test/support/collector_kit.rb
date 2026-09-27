# frozen_string_literal: true

require "fun_ci/evidence/collector"
require "fun_ci/evidence/process_table"
require "fun_ci/evidence/detection"
require_relative "fake_stage_dir"

# Collectors for a fast suite, in memory: settings from a hash, the stage's
# entries from a list, and the sources a test names.
module CollectorKit
  SOURCES = FunCi::Evidence::Sources
  SETTINGS = FunCi::Evidence::Settings
  GREP = { "use" => "grep", "patterns" => ["ERROR"] }.freeze
  OVERRUN_GREP = GREP.merge("on" => "overrun").freeze
  PROCESSES = [FunCi::Evidence::ProcessTable::Row.new(pid: 42, ppid: 1, pgid: 42, seconds: 9, command: "sh fast.sh"),
               FunCi::Evidence::ProcessTable::Row.new(pid: 43, ppid: 42, pgid: 42, seconds: 8, command: "java Worker")]
              .freeze

  # A clock that moves on a second each time it is read.
  class TickingClock
    def initialize = @now = 0
    def call = @now += 1
  end

  def collect(output, entries: [], settings: {}, **given)
    collector(settings: settings.merge("stages" => { "fast" => entries }), **given).collect(output)
  end

  # given: the sources' reports, environment and worktree, where a test names them.
  def collector(settings: {}, clock: -> { 0 }, **given)
    sources = SOURCES.new(stage: "fast", worktree: "/slot-0", reports: FakeStageDir.new, environment: {}, **given)
    FunCi::Evidence::Collector.new(sources, settings: SETTINGS.new(settings), clock: clock)
  end
end
