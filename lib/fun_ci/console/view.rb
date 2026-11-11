# frozen_string_literal: true

module FunCi
  module Console
    # What the user sees of the rows and does with them: KeyHandler's cursor,
    # what it asks and which job rows it keeps in view, and one page of rows, one per branch, as many as
    # the terminal fits, scrolled so the row under the cursor is on it
    # (renderer-protocol.md, `board`).
    class View
      # The renderer's 14-row header, the footer and the lines around the
      # table: a page this many rows short of the terminal fits one line per
      # row, however the renderer spaces them (renderer-protocol.md, `board`).
      CHROME_ROWS = 18
      # A blank line and one for the job section, the least the renderer folds it to.
      JOB_LINES = 2

      def initialize(key_handler:)
        @key_handler = key_handler
        @page_size = 0
      end

      # The least a page holds: the renderer fits what it can of a run, and
      # a page of none would read as no runs at all.
      LEAST = 1

      # The number of runs a terminal of `rows` fits.
      def resize(rows)
        @page_size = [rows - CHROME_ROWS, LEAST].max
      end

      # :quit when the key ends the session.
      def press(key) = @key_handler.handle_key(key)

      # The job rows in view: not the hidden ones, unless the user asked for them.
      def shown(job_rows) = @key_handler.shown(job_rows)

      # The branches' runs in view: not those of hidden branches, unless the user asked for them.
      def shown_runs(runs) = @key_handler.shown_runs(runs)

      # `more`: whether the store holds runs beyond `runs`. `jobs`: the job
      # section's rows in view, below the page, which the cursor reaches after the runs.
      def page(runs, more:, jobs: [])
        @key_handler.follow(runs, jobs)
        size = jobs.empty? ? @page_size : [@page_size - JOB_LINES, LEAST].max
        first = first_shown(runs.size, size)
        { cursor: cursor_on_page(first, size), confirming: @key_handler.confirming?, **hiding,
          has_more: more || first + size < runs.size, runs: runs[first, size] || [] }
      end

      private

      # Only while the footer asks how to hide a job, as the protocol lets a board leave it out.
      def hiding = @key_handler.asking == :hide ? { hiding: true } : {}

      # The last page of runs while the cursor is on a job.
      def first_shown(count, size)
        cursor = @key_handler.cursor_index
        return 0 unless cursor

        [[cursor, count - 1].min - size + 1, 0].max
      end

      # Past the page's runs while the cursor is on a job: a page that holds
      # a job's cursor ends at the last run.
      def cursor_on_page(first, size)
        cursor = @key_handler.cursor_index
        cursor - first if cursor && size.positive?
      end
    end
  end
end
