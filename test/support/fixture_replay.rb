# frozen_string_literal: true

require "json"
require "fun_ci/console/console_session"
require "fun_ci/console/streak_counter"
require "fun_ci/console/cancelled_folding"
require "fun_ci/console/row_order"
require_relative "console_fakes"
require "fun_ci/jobs/standings"

# Replays a contract fixture (contract/fixtures/*.jsonl) against
# ConsoleSession: `state` lines set what the database holds and the clock
# (each after the first is a poll), `renderer` lines are fed in, and the
# conversation is the renderer lines with every message Ruby sent in between.
class FixtureReplay
  # BoardData over the fixture's runs, the database's runs newest first, all
  # of them loaded: one row per branch, as BoardData makes them; and where
  # its jobs stand, as JobRows makes them.
  class Store
    attr_writer :runs
    attr_accessor :now, :stale, :job_rows

    def initialize
      @runs = []
      @now = 0
    end

    def runs
      branches = @runs.group_by { |run| run.values_at(:project_path, :branch) }.values
      FunCi::Console::RowOrder.of(branches.map { |branch| FunCi::Console::CancelledFolding.fold(branch).first })
    end

    def streak = FunCi::Console::StreakCounter.count(@runs)
    def load_more = nil
    def resize(_page_size) = nil
    def more? = false
    def record_dead_slow_suites = nil
    def record_dead_jobs = nil
    def cancel_run(_id) = nil
    def cancel_job(_id) = nil
    def jobs(_runs) = job_rows || []
    def stale_trunks(_runs, now:) = now && (stale || [])
  end

  Port = Struct.new(:conversation) do
    def write(message) = conversation << { "ruby" => JSON.parse(JSON.generate(message)) }
  end

  def self.lines(path) = File.readlines(path).map { |line| JSON.parse(line) }

  def initialize(lines)
    @lines = lines
    @store = Store.new
    @port = Port.new([])
  end

  # What the fixture says the conversation is.
  def expected = @lines.reject { |line| line.key?("state") }

  def conversation
    session = FunCi::Console::ConsoleSession.build(board_data: @store, port: @port, clock: -> { @store.now },
                                                   log: ConsoleFakes::Log.new)
    @lines.each_with_index { |line, index| play(session, line, index) }
    @port.conversation
  end

  private

  def play(session, line, index)
    return state(session, line["state"], index) if line.key?("state")
    return unless line.key?("renderer")

    @port.conversation << line
    session.receive(JSON.generate(line["renderer"]))
  end

  # A job of the fixture's state ({ project, name, cadence, run }) where it stands at `now`.
  def standing(job, now)
    run = job["run"] && JSON.parse(JSON.generate(job["run"]), symbolize_names: true)
    found = FunCi::Jobs::Job.new(name: job["name"], cadence: job["cadence"], script: "")
    FunCi::Jobs::Standing.new(project: job["project"], job: found, run: run,
                              due: FunCi::Jobs::Due.new(run, found.period, now: Time.at(now)))
  end

  def state(session, state, index)
    @store.runs = state["runs"].map { |run| JSON.parse(JSON.generate(run), symbolize_names: true) }
    @store.now = state["now"]
    @store.stale = state.fetch("stale_trunks", []).map { |stale| stale.transform_keys(&:to_sym) }
    @store.job_rows = state.fetch("jobs", []).map { |job| standing(job, state["now"]) }
    index.zero? ? session.start : session.refresh
  end
end
