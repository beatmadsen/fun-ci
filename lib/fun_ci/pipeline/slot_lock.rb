# frozen_string_literal: true

module FunCi
  module Pipeline
    # Whether some process holds a slot's lock, which is whether the run that
    # took the slot is still alive: an flock dies with its holders.
    module SlotLock
      def self.held?(path)
        File.exist?(path) && File.open(path) { |lock| !lock.flock(File::LOCK_EX | File::LOCK_NB) }
      end
    end
  end
end
