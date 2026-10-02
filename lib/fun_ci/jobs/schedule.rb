# frozen_string_literal: true

module FunCi
  module Jobs
    # When each of the jobs a commit starts begins (design.md, Daily and
    # weekly jobs): one at a time, `spacing` seconds apart, and no sooner
    # than `spacing` after the latest start of the project's jobs already
    # running or waiting to (`begun`), so their work is spread over time
    # rather than taking every core at once. A spacing of 0 starts all now.
    class Schedule
      def initialize(spacing, begun, now:)
        @spacing = spacing
        @begun = begun
        @now = now
      end

      # [job, its start] for each of `jobs`, in their order.
      def starts(jobs) = jobs.each_with_index.map { |job, index| [job, first + (index * @spacing)] }

      private

      def first = @begun.empty? ? @now : [@now, @begun.max + @spacing].max
    end
  end
end
