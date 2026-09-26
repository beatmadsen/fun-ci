# frozen_string_literal: true

require "sqlite3"
require "stringio"

module FunCi
  module Persistence
    # What happens when the database won't take a write (acceptance-tests.md,
    # AT-8.2, AT-8.4): the pipeline carries on without recording it, and the
    # developer is told once, with what to do about it.
    class WriteTrouble
      UNWRITABLE = [SQLite3::FullException, SQLite3::ReadOnlyException, SQLite3::IOException,
                    SQLite3::CantOpenException].freeze
      BUSY = "fun-ci: couldn't record this run: the database stayed busy. Your stages still ran. " \
             "Trigger it again to record it."
      STILL_RAN = "Check the disk has space. Your stages still ran."

      # Says nothing, for a process whose output nobody reads.
      def self.silent(db_path) = new(StringIO.new, db_path)

      def initialize(out, db_path)
        @out = out
        @db_path = db_path
        @told = false
      end

      # The block's value, or nil when the database refused the write.
      def guard
        yield
      rescue SQLite3::BusyException
        tell(BUSY)
      rescue *UNWRITABLE
        tell("fun-ci: can't write to the database at #{@db_path}. #{STILL_RAN}")
      end

      private

      def tell(message)
        @out.puts(message) unless @told
        @told = true
        nil
      end
    end
  end
end
