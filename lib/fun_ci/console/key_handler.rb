# frozen_string_literal: true

require_relative "cursor"
require_relative "cursor_rows"
require_relative "question"

module FunCi
  module Console
    # What a key means for the runs BoardData loads, and the daily and weekly
    # jobs after them: moving the cursor through both, quitting, cancelling
    # the run or job under the cursor (a running one after the user confirms
    # with `y`), hiding the job under it (`h`, then `s` to snooze it or `i` to
    # ignore it), and showing the hidden jobs (`a`), where `h` brings one back.
    # The cursor stays on its row as the rows move, and a question ends when
    # the row it asks about is no longer under the cursor as it was.
    class KeyHandler
      def initialize(board_data:)
        @board_data = board_data
        @question = nil
        @revealed = false
      end

      # The index of the row under the cursor among the runs and the job rows in view; nil without a cursor.
      def cursor_index = @cursor&.index

      # :quit when the key ends the session.
      def handle_key(key)
        return :quit if key == "q"

        rows = self.rows
        follow(rows.runs, rows.jobs)
        return answer(key) if @question

        act(key, rows)
      end

      # Puts the cursor back on its row among `runs` and the job rows in view, `jobs`.
      def follow(runs, jobs)
        rows = CursorRows.new(runs, jobs)
        @cursor = @cursor&.within(rows)
        @question = nil unless @question&.about?(rows.at(cursor_index))
      end

      # What the footer asks, :cancel or :hide; nil while it asks nothing.
      def asking = @question&.asks

      def confirming? = asking == :cancel

      # The job rows in view: not the hidden ones, unless `a` asked for them.
      def shown(job_rows) = @revealed ? job_rows : job_rows.reject(&:hidden)

      private

      def act(key, rows)
        case key
        when "j", :down then move_cursor_down(rows)
        when "k", :up then move_cursor_up(rows)
        when "c" then initiate_cancel(rows)
        when "h" then hide_or_show(rows)
        when "a" then settle(revealed: !@revealed)
        end
      end

      def answer(key)
        @question.take(key)
        return unless @question.ended_by?(key)

        @question = nil
        settle
      end

      # After job rows left the view or came into it: hidden jobs are shown
      # only while some job is hidden, and the cursor stays on a row.
      def settle(revealed: @revealed)
        runs = @board_data.runs
        jobs = @board_data.jobs(runs)
        @revealed = revealed && jobs.any?(&:hidden)
        follow(runs, shown(jobs))
      end

      def rows
        runs = @board_data.runs
        CursorRows.new(runs, shown(@board_data.jobs(runs)))
      end

      # Onto the last run loaded, which loads the next page, then into the jobs.
      def move_cursor_down(rows)
        return @cursor = Cursor.at(rows, 0) unless @cursor
        return unless cursor_index < rows.last

        @cursor = Cursor.at(rows, cursor_index + 1)
        @board_data.load_more if cursor_index == rows.runs.length - 1
      end

      def move_cursor_up(rows)
        @cursor = Cursor.at(rows, cursor_index - 1) if cursor_index&.positive?
      end

      def initiate_cancel(rows)
        kind, row = rows.at(cursor_index)
        return unless row

        kind == :job ? offer_cancel(kind, row, row.state) : offer_cancel(kind, row, row[:status])
      end

      # A run or job waiting to start is cancelled at once, nothing of it
      # having run; a running one once the user confirms.
      def offer_cancel(kind, row, status)
        cancel = Question::Cancel.new(@board_data, kind, row)
        cancel.carry_out if status == "scheduled"
        @question = cancel if status == "running"
      end

      # Asks how to hide the job under the cursor; one already hidden comes back at once.
      def hide_or_show(rows)
        kind, job = rows.at(cursor_index)
        return unless kind == :job && job
        return @question = Question::Hide.new(@board_data, job) unless job.hidden

        @board_data.show_job(job)
        settle
      end
    end
  end
end
