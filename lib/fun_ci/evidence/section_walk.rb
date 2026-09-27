# frozen_string_literal: true

module FunCi
  module Evidence
    # Finds sections line by line: one opens on a start line, and closes
    # before an end line or once it is `limit` lines long (cut); the line
    # that closes one may open the next, so back-to-back items each get one.
    class SectionWalk
      # first, last: line indexes; cut: whether the limit closed it.
      Found = Data.define(:first, :last, :cut)

      def initialize(starts, ends, limit)
        @starts = starts
        @ends = ends
        @limit = limit
        @found = []
      end

      def step(line, index)
        carry_on(line, index) if open?
        @found << Found.new(first: index, last: nil, cut: false) if !open? && matches?(@starts, line)
      end

      # The sections found, the one still open ending at the last line, each
      # without the blank lines it ends with.
      def finish(lines)
        close(lines.size - 1, cut: false) if open?
        @found.map { |found| found.with(last: last_written(lines, found)) }
      end

      private

      def carry_on(line, index)
        return close(index - 1, cut: false) if matches?(@ends, line)

        close(index - 1, cut: true) if index - @found.last.first >= @limit
      end

      def matches?(patterns, line) = patterns.any? { |pattern| pattern.match?(line) }

      def last_written(lines, found)
        found.last.downto(found.first).find { |index| !lines[index].strip.empty? } || found.first
      end

      def open? = !@found.empty? && @found.last.last.nil?
      def close(last, cut:) = @found[-1] = @found.last.with(last: last, cut: cut)
    end
  end
end
