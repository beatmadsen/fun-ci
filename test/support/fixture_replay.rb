# frozen_string_literal: true

require "json"
require "fun_ci/console/console_session"
require "fun_ci/console/streak_counter"
require_relative "console_fakes"

# Replays a contract fixture (contract/fixtures/*.jsonl) against
# ConsoleSession: `state` lines set what the database holds and the clock
# (each after the first is a poll), `renderer` lines are fed in, and the
# conversation is the renderer lines with every message Ruby sent in between.
class FixtureReplay
  # BoardData over the fixture's runs, as SQLite would return them, all of
  # them loaded.
  class Store
    attr_accessor :runs, :now

    def initialize
      @runs = []
      @now = 0
    end

    def streak = FunCi::Console::StreakCounter.count(runs)
    def load_more = nil
    def resize(_page_size) = nil
    def more? = false
    def record_dead_slow_suites = nil
    def cancel_run(_id) = nil
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

  def state(session, state, index)
    @store.runs = state["runs"].map { |run| JSON.parse(JSON.generate(run), symbolize_names: true) }
    @store.now = state["now"]
    index.zero? ? session.start : session.refresh
  end
end
