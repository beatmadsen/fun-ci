# frozen_string_literal: true

require_relative "collector"
require_relative "settings"
require_relative "worktree"

module FunCi
  module Evidence
    # What happens when a stage starts, so its evidence can be collected if
    # it fails: its settings are read from the worktree, so they are the
    # commit's own, and the files it watches are stamped.
    module Start
      def self.collector(sources, clock)
        settings = Settings.load(File.join(sources.worktree, ".fun-ci", "config"))
        Collector.new(sources.with(watched: stamps(Worktree.new(sources.worktree), settings.watched(sources.stage))),
                      settings: settings, clock: clock)
      end

      def self.stamps(worktree, globs)
        globs.flat_map { |glob| worktree.glob(glob) }.uniq.to_h { |path| [path, worktree.stamp(path)] }
      end
      private_class_method :stamps
    end
  end
end
