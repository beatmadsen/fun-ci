# frozen_string_literal: true

require "json"

# Stand-ins for ConsoleSession's collaborators: a BoardData that serves
# fixed runs and records cancels and pages loaded, and a renderer port that keeps each message
# as the JSON the renderer would read.
module ConsoleFakes
  class BoardData
    attr_reader :cancelled, :loads
    attr_accessor :runs

    def initialize(runs)
      @runs = runs
      @cancelled = []
      @loads = 0
    end

    def streak = 3
    def load_more = @loads += 1
    def resize(_page_size) = nil
    def more? = false
    def cancel_run(id) = @cancelled << id
  end

  class Port
    attr_reader :sent

    def initialize
      @sent = []
    end

    def write(message) = @sent << JSON.parse(JSON.generate(message))
  end

  class Log
    attr_reader :lines

    def initialize
      @lines = []
    end

    def write(text) = @lines << text
  end

  def self.run_row(id, status: "completed")
    { id: id, commit_hash: "a" * 40, branch: "main", status: status, project_path: nil,
      created_at: "2026-09-25T10:00:00Z", updated_at: "2026-09-25T10:01:00Z", stages: [] }
  end

  # A run whose `fast` stage has `status`.
  def self.fast_stage(id, status)
    run_row(id, status: "running").merge(stages: [{ stage: "fast", status: status, duration: nil,
                                                    started_at: "2026-09-25T10:00:00Z" }])
  end
end
