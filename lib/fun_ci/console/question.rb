# frozen_string_literal: true

module FunCi
  module Console
    # What the footer asks about the row under the cursor before a key acts
    # on it (design.md, The console). Each says what it `asks`, does what a
    # key it is given answers (`take`), and says whether that key ends it.
    module Question
      # Whether to cancel a running run or job, whose processes get killed: `y` does.
      class Cancel
        ENDS = ["y", "n", :escape].freeze

        # kind: :run or :job; row: the run, or the job's row.
        def initialize(board_data, kind, row)
          @board_data = board_data
          @kind = kind
          @row = row
        end

        def asks = :cancel

        def take(key) = key == "y" && carry_out
        def ended_by?(key) = ENDS.include?(key)

        def carry_out = @kind == :job ? @board_data.cancel_job(@row.run[:id]) : @board_data.cancel_run(@row[:id])
      end

      # How to hide a job: `s` snoozes it, until it runs again; `i` ignores it, for good.
      class Hide
        KINDS = { "s" => "snoozed", "i" => "ignored" }.freeze
        ENDS = [*KINDS.keys, "n", :escape].freeze

        def initialize(board_data, job)
          @board_data = board_data
          @job = job
        end

        def asks = :hide

        def take(key) = KINDS.key?(key) && @board_data.hide_job(@job, KINDS[key])
        def ended_by?(key) = ENDS.include?(key)
      end
    end
  end
end
