# frozen_string_literal: true

# Reads a FIFO to its end. Opening one blocks until a writer opens it, and on
# Ruby 3.2 and 3.3 under Linux a child exiting meanwhile interrupts the open
# with EINTR instead of resuming it; the open is simply tried again.
module Fifo
  def self.read(path)
    File.read(path)
  rescue Errno::EINTR
    retry
  end
end
