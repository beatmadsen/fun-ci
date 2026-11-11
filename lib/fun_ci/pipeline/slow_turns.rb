# frozen_string_literal: true

require "digest"
require "fileutils"

module FunCi
  module Pipeline
    # The turns a branch's slow suites take: one runs at a time, and a newer
    # one waits while an older one runs (acceptance-tests.md, AT-9.19). A turn
    # is an flock on the branch's file under `root`, so it ends with the
    # process that held it, a slow suite cancelled while it waits included.
    class SlowTurns
      def initialize(root)
        @root = root
      end

      # Yields once no other process holds the branch's turn, holding it until the block returns.
      def take(branch)
        FileUtils.mkdir_p(@root)
        File.open(lock_path(branch), File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          yield
        end
      end

      def lock_path(branch) = File.join(@root, "#{Digest::SHA256.hexdigest(branch)[0, 16]}.lock")
    end
  end
end
