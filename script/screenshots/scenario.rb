# frozen_string_literal: true

require "digest"
require "json"

module Screenshots
  # One stage of a run, from a word such as "lint:0.4" (passed in 0.4 s),
  # "fast:fail@2.1", "build:running" or "slow:pending".
  Stage = Data.define(:stage, :status, :seconds) do
    def self.parse(word)
      stage, state = word.split(":")
      return new(stage, state, nil) if %w[running pending].include?(state)
      return new(stage, "failed", Float(state.delete_prefix("fail@"))) if state.start_with?("fail@")

      new(stage, "passed", Float(state))
    end

    def to_h(now)
      case status
      when "running" then { stage:, status:, started_at: now - 1 }
      when "pending" then { stage:, status: }
      else { stage:, status:, duration_ms: (seconds * 1000).round }
      end
    end
  end

  # A run on the board, which finished (or last changed) `ago` seconds before
  # the board's clock.
  Run = Data.define(:id, :branch, :stages, :ago) do
    def self.of(id, branch, words, ago: 0)
      new(id, branch, words.split.map { |word| Stage.parse(word) }, ago)
    end

    def status
      states = stages.map(&:status)
      return "failed" if states.include?("failed")

      states.intersect?(%w[running pending]) ? "running" : "passed"
    end

    def to_h(now)
      { id:, sha: Digest::SHA1.hexdigest("run #{id}"), branch:, status:, started_at: now - ago - 60,
        updated_at: now - ago, stages: stages.map { |stage| stage.to_h(now) } }
    end
  end

  # A scenario for fun-ci-renderer's headless mode (docs/renderer-protocol.md,
  # Scenario files): boards, events and ticks, one JSON line each.
  class Scenario
    START = 1_790_000_000

    def initialize(cols:, rows:)
      @lines = [{ t: "resize", cols:, rows: }]
      @elapsed_ms = 0
    end

    def size = @lines.first.values_at(:cols, :rows)

    def board(runs, streak:)
      @lines << { t: "board", now:, project: "/src/shop", streak:, cursor: 0, confirming: false,
                  has_more: false, runs: runs.map { |run| run.to_h(now) } }
      self
    end

    def event(name, **fields)
      @lines << { t: "event", name:, **fields }
      self
    end

    def ticks(count)
      @lines.concat(Array.new(count) { { t: "tick", ms: 100 } })
      @elapsed_ms += count * 100
      self
    end

    def frames = @elapsed_ms / 100

    def to_s = "#{@lines.map { |line| JSON.generate(line) }.join("\n")}\n"

    private

    def now = START + (@elapsed_ms / 1000)
  end
end
