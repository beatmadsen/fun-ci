# frozen_string_literal: true

module FunCi
  module Console
    # What the user sees of the runs and does with them: KeyHandler's cursor
    # and cancel confirmation, and one page of runs, as many as the terminal
    # fits, scrolled so the run under the cursor is on it (renderer-protocol.md,
    # `board`).
    class View
      # The renderer's 14-row header, a blank line and the footer.
      CHROME_ROWS = 16
      ROWS_PER_RUN = 2

      def initialize(key_handler:)
        @key_handler = key_handler
        @page_size = 0
      end

      # The number of runs a terminal of `rows` fits.
      def resize(rows)
        @page_size = [(rows - CHROME_ROWS) / ROWS_PER_RUN, 0].max
      end

      # :quit when the key ends the session.
      def press(key) = @key_handler.handle_key(key)

      # `more`: whether the store holds runs beyond `runs`.
      def page(runs, more:)
        first = first_shown
        { cursor: cursor_on_page(first), confirming: @key_handler.confirming?,
          has_more: more || first + @page_size < runs.size, runs: runs[first, @page_size] || [] }
      end

      private

      def first_shown
        cursor = @key_handler.cursor_index
        cursor ? [cursor - @page_size + 1, 0].max : 0
      end

      def cursor_on_page(first)
        cursor = @key_handler.cursor_index
        cursor - first if cursor && @page_size.positive?
      end
    end
  end
end
