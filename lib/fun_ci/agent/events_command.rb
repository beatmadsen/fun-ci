# frozen_string_literal: true

require "json"
require_relative "command_support"
require_relative "snapshots"
require_relative "events"
require_relative "waiting"

module FunCi
  module Agent
    # `fun-ci events [--follow] [--only failures]` (acceptance-tests.md,
    # AT-9.16): one JSON line per event of the project's recent runs, then,
    # with --follow, each new one as it happens, until interrupted.
    class EventsCommand
      include CommandSupport

      NAME = "events"
      SCHEMA = 1
      RECENT_RUNS = 10

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[follow only json])
        seen = emit({}, options.only)
        follow(seen, options.only) if options.follow
        0
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def follow(seen, only)
        loop do
          @context.clock.pause(Waiting::POLL_SECONDS)
          @context.pipeline.watch(@context.db)
          seen = emit(seen, only)
        end
      rescue Interrupt
        # Following ends when whoever follows stops it.
      end

      # Prints what happened since `before`, and answers the look it took.
      def emit(before, only)
        after = snapshots.take(limit: RECENT_RUNS)
        Events.between(before, after).select { |event| !only || Events.failure?(event) }.each { |event| print(event) }
        after
      end

      def print(event)
        @context.io.stdout.puts JSON.generate({ schema: SCHEMA, **event })
        @context.io.stdout.flush
      end

      def snapshots = @snapshots ||= Snapshots.new(@context.db, @context.git)
    end
  end
end
