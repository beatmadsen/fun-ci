# frozen_string_literal: true

module FunCi
  module Persistence
    # Where fun-ci keeps its database: the user's state directory, which every
    # process of that user agrees on (acceptance-tests.md, AT-9.1).
    module StateDir
      def self.path(env)
        base = env["XDG_STATE_HOME"].to_s
        base = File.join(env.fetch("HOME"), ".local", "state") if base.empty?
        File.join(base, "fun-ci")
      end
    end
  end
end
