# frozen_string_literal: true

module FunCi
  module Console
    # The rows the cursor moves through: the runs loaded, then the job rows in view.
    CursorRows = Data.define(:runs, :jobs)

    class CursorRows
      # The last row's index; negative when there is no row.
      def last = runs.length + jobs.length - 1

      # [:run, the run] or [:job, the job's row] at `index`; none without one.
      def at(index)
        return [] unless index
        return [:run, runs[index]] if index < runs.length

        [:job, jobs[index - runs.length]]
      end

      # `index`, or the last row's when it is past it; nil when there is no row.
      def within(index) = index && !last.negative? ? [index, last].min : nil
    end
  end
end
