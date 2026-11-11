# frozen_string_literal: true

module FunCi
  module Console
    # Where the cursor is among CursorRows: its row's index, and which row
    # that is (CursorRows#key_at), so it stays on that row when the rows move
    # under it.
    Cursor = Data.define(:index, :on)

    class Cursor
      # The cursor on the row at `index`, or on the last row when `index` is
      # past it; none when there is no row.
      def self.at(rows, index)
        within = rows.within(index)
        within && new(within, rows.key_at(within))
      end

      # The cursor on its row where `rows` hold it, or at its index when that row left them.
      def within(rows) = Cursor.at(rows, rows.index_of(on) || index)
    end
  end
end
