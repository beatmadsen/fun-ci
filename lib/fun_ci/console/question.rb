# frozen_string_literal: true

require_relative "cursor_rows"

module FunCi
  module Console
    # What the footer asks about the row under the cursor before a key acts
    # on it (design.md, The console). Each says what it `asks`, does what a
    # key it is given answers (`take`), and says whether that key ends it.
    module Question
      # What each question holds, the board it acts on and the row it asks
      # about, and which keys end it: its class's ENDS.
      module Asked
        # kind: :run or :job; row: the branch's run, or the job's row.
        def initialize(board_data, kind, row)
          @board_data = board_data
          @kind = kind
          @row = row
        end

        def ended_by?(key) = self.class::ENDS.include?(key)
      end

      # Whether to cancel a running run or job, whose processes get killed: `y` does.
      class Cancel
        include Asked

        ENDS = ["y", "n", :escape].freeze

        def asks = :cancel

        def take(key) = key == "y" && carry_out

        def carry_out = @kind == :job ? @board_data.cancel_job(@row.run[:id]) : @board_data.cancel_run(@row[:id])

        # Whether `place`, [kind, row] under the cursor now, is still the run asked about, running.
        def about?(place) = place.first == @kind && Cancel.target(*place) == Cancel.target(@kind, @row)

        # A run's id and status, or a job's latest run's id and its state.
        def self.target(kind, row) = kind == :job ? [row.run&.dig(:id), row.state] : row.values_at(:id, :status)
      end

      # How to hide a branch or a job: `s` snoozes it, until its next run; `i` ignores it, until shown again.
      class Hide
        include Asked

        KINDS = { "s" => "snoozed", "i" => "ignored" }.freeze
        ENDS = [*KINDS.keys, "n", :escape].freeze

        def asks = :hide

        def take(key) = KINDS.key?(key) && hide(KINDS[key])

        # Whether `place`, [kind, row] under the cursor now, is still the branch or job asked about.
        def about?(place) = place.first == @kind && CursorRows.key(*place) == CursorRows.key(@kind, @row)

        private

        def hide(how) = @kind == :job ? @board_data.hide_job(@row, how) : @board_data.hide_run(@row, how)
      end
    end
  end
end
