# frozen_string_literal: true

require "fileutils"

module FunCi
  module Persistence
    # Where fun-ci keeps its database: the user's state directory, which every
    # process of that user agrees on (acceptance-tests.md, AT-9.1). Only that
    # user can read it, since what fun-ci keeps can hold a secret masking missed.
    module StateDir
      MODE = 0o700

      # Creates the directory if need be, and makes it the user's alone.
      def self.prepare(path)
        FileUtils.mkdir_p(path)
        File.chmod(MODE, path)
      end

      def self.path(env)
        base = env["XDG_STATE_HOME"].to_s
        base = File.join(env.fetch("HOME"), ".local", "state") if base.empty?
        File.join(base, "fun-ci")
      end
    end
  end
end
