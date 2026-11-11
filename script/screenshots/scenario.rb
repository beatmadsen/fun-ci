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

  # A scenario the contract already records (contract/scenarios/), replayed
  # on a screen of its own size.
  # A board with no cursor is given the first row's, as the console opens.
  class Replayed
    def initialize(name, cols:, rows:)
      @path = File.expand_path("../../contract/scenarios/#{name}.jsonl", __dir__)
      @size = [cols, rows]
    end

    attr_reader :size

    def to_s
      lines = [{ "t" => "resize", "cols" => @size.first, "rows" => @size.last }]
      File.readlines(@path).map { |line| JSON.parse(line) }.each { |line| lines << line unless line["t"] == "resize" }
      lines.map { |line| JSON.generate(opened(line)) }.join("\n") << "\n"
    end

    private

    def opened(line) = line["t"] == "board" && line["cursor"].nil? ? line.merge("cursor" => 0) : line
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

    # `view` overrides the cursor and question fields (cursor, hiding,
    # hidden_rows); runs and jobs are anything with `to_h(now)`.
    def board(runs, streak:, jobs: [], **view)
      line = { t: "board", now:, project: "/src/shop", streak:, cursor: 0, confirming: false,
               has_more: false, **view, runs: runs.map { |run| run.to_h(now) } }
      line[:jobs] = jobs.map { |job| job.to_h(now) } unless jobs.empty?
      @lines << line
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
