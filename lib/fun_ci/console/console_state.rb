# frozen_string_literal: true

require_relative "run_message"
require_relative "console_events"
require_relative "job_message"

module FunCi
  module Console
    # What the console shows: the page of runs BoardData reads that the View
    # puts on screen, the daily and weekly jobs in view below it, and the clock's
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

      # The events of the branches in view, hidden or not shown, so `a` plays no scene; then the board.
      def updates
        @board_data.record_dead_slow_suites
        @board_data.record_dead_jobs
        branches = @board_data.branch_page
        runs = branches.runs
        [*@events.since_last(runs.reject { |run| run[:hidden] }), board(branches, @board_data.jobs(runs))]
      end

      private

      def board(branches, job_rows)
        runs = branches.runs
        shown = @view.shown(job_rows)
        page = @view.page(@view.shown_runs(runs), more: branches.more, jobs: shown)
        { t: "board", now: @clock.call.to_i, streak: @board_data.streak, **page,
          runs: page[:runs].map { |run| RunMessage.from(run) }, **job_section(shown),
          **hidden_rows(runs, job_rows), **stale_trunks(runs) }
      end

      # Only when there are jobs in view, as the protocol lets a board leave them out.
      def job_section(rows)
        rows.empty? ? {} : { jobs: rows.map { |row| JobMessage.from(row.standing, hidden: row.hidden) } }
      end

      # How many branches and jobs the user hid, in view or not; only when some
      # are, as the protocol lets a board leave it out.
      def hidden_rows(runs, job_rows)
        count = runs.count { |run| run[:hidden] } + job_rows.count(&:hidden)
        count.zero? ? {} : { hidden_rows: count }
      end

      # Only when a trunk is stale, as the protocol lets a board leave it out.
      def stale_trunks(runs)
        stale = @board_data.stale_trunks(runs, now: @clock.call)
        stale.empty? ? {} : { stale_trunks: stale }
      end
    end
  end
end
