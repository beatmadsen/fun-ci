# frozen_string_literal: true

require_relative "run_message"
require_relative "console_events"
require_relative "job_message"

module FunCi
  module Console
    # What the console shows: the page of runs BoardData reads that the View
    # puts on screen, the daily and weekly jobs below it, and the clock's
    # time, as a protocol `board` message, after the `event`s for what changed
    # since the last one.
    class ConsoleState
      KEYS = { "up" => :up, "down" => :down, "esc" => :escape, "ctrl_c" => "q", "enter" => :enter }.freeze

      def initialize(board_data:, view:, clock:)
        @board_data = board_data
        @view = view
        @clock = clock
        @events = ConsoleEvents.new
      end

      # :quit when the key ends the session.
      def press(key) = @view.press(KEYS.fetch(key, key))

      # Pages for a terminal of `rows`.
      def resize(rows) = @board_data.resize(@view.resize(rows))

      def updates
        @board_data.record_dead_slow_suites
        @board_data.record_dead_jobs
        runs = @board_data.runs
        [*@events.since_last(runs), board(runs, @board_data.jobs(runs))]
      end

      private

      def board(runs, jobs)
        page = @view.page(runs, more: @board_data.more?, jobs: jobs)
        { t: "board", now: @clock.call.to_i, streak: @board_data.streak, **page,
          runs: page[:runs].map { |run| RunMessage.from(run) }, **job_section(jobs), **stale_trunks(runs) }
      end

      # Only when there are jobs, as the protocol lets a board leave them out.
      def job_section(jobs) = jobs.empty? ? {} : { jobs: jobs.map { |job| JobMessage.from(job) } }

      # Only when a trunk is stale, as the protocol lets a board leave it out.
      def stale_trunks(runs)
        stale = @board_data.stale_trunks(runs, now: @clock.call)
        stale.empty? ? {} : { stale_trunks: stale }
      end
    end
  end
end
