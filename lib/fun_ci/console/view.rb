# frozen_string_literal: true

module FunCi
  module Console
    # What the user sees of the rows and does with them: KeyHandler's cursor
    # and cancel confirmation, and one page of rows, one per branch, as many as
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

      # The number of runs a terminal of `rows` fits.
      def resize(rows)
        @page_size = [rows - CHROME_ROWS, 0].max
      end

      # :quit when the key ends the session.
      def press(key) = @key_handler.handle_key(key)

      # `more`: whether the store holds runs beyond `runs`. `jobs`: the job
      # section's rows, below the page, which the cursor reaches after the runs.
      def page(runs, more:, jobs: [])
        size = jobs.empty? ? @page_size : [@page_size - JOB_LINES, 0].max
        first = first_shown(runs.size, size)
        { cursor: cursor_on_page(first, size, runs.size), confirming: @key_handler.confirming?,
          has_more: more || first + size < runs.size, runs: runs[first, size] || [] }
      end

      private

      # The last page of runs while the cursor is on a job.
      def first_shown(count, size)
        cursor = @key_handler.cursor_index
        return 0 unless cursor

        [[cursor, count - 1].min - size + 1, 0].max
      end

      # Past the page's runs while the cursor is on a job.
      def cursor_on_page(first, size, count)
        cursor = @key_handler.cursor_index
        return nil unless cursor && size.positive?

        cursor < count ? cursor - first : [count - first, size].min + cursor - count
      end
    end
  end
end
