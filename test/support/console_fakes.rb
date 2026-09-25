# frozen_string_literal: true

require "json"

# Stand-ins for ConsoleSession's collaborators: a BoardData that serves
# fixed runs and records cancels, and a renderer port that keeps each message
# as the JSON the renderer would read.
module ConsoleFakes
  class BoardData
    attr_reader :cancelled, :runs

    def initialize(runs)
      @runs = runs
      @cancelled = []
    end

    def streak = 3
    def load_more = nil
    def cancel_run(id) = @cancelled << id
  end

  class Port
    attr_reader :sent

    def initialize
      @sent = []
    end

    def write(message) = @sent << JSON.parse(JSON.generate(message))
  end

  def self.run_row(id, status: "completed")
    { id: id, commit_hash: "a" * 40, branch: "main", status: status, project_path: nil,
      created_at: "2026-09-25T10:00:00Z", updated_at: "2026-09-25T10:01:00Z", stages: [] }
  end
end
