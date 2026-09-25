# frozen_string_literal: true

require "sqlite3"

# Every SQLite connection a test opens must be closed by the end of that
# test. One left open is inherited by the next fork in the same parallel
# worker, and sqlite3 then warns about fork safety, depending on test order.
module SqliteConnectionGuard
  @opened = []

  class << self
    attr_reader :opened
  end

  module TrackOpened
    def initialize(...)
      super
      SqliteConnectionGuard.opened << self
    end
  end

  module CheckAfterTest
    def after_teardown
      super
      leaked = SqliteConnectionGuard.take_leaked
      flunk "#{self.class}##{name} left #{leaked} SQLite connection open" if leaked.positive?
    end
  end

  def self.install
    SQLite3::Database.prepend(TrackOpened)
    Minitest::Test.prepend(CheckAfterTest)
  end

  def self.take_leaked
    leaked = opened.reject(&:closed?)
    leaked.each(&:close)
    opened.clear
    leaked.size
  end
end
