# frozen_string_literal: true

require_relative "collector"
require_relative "settings"
require_relative "worktree"
require_relative "detection"

module FunCi
  module Evidence
    # What happens when a stage starts, so its evidence can be collected if
    # it fails: its settings are read from the worktree, so they are the
    # commit's own, and the files it watches are stamped.
    module Start
      def self.collector(sources, clock, commands)
        settings = Settings.load(File.join(sources.worktree, ".fun-ci", "config"))
        worktree = Worktree.new(sources.worktree)
        Collector.new(sources.with(watched: stamps(worktree, settings.watched(sources.stage)),
                                   candidates: candidates(worktree, settings, sources.stage)),
                      settings: settings, clock: clock, commands: commands)
      end

      # The presets that may run: detected ones, less those skipped or configured.
      def self.candidates(worktree, settings, stage)
        return [] unless settings.detect?

        left_out = settings.skip + settings.entries(stage).grep(Hash).filter_map { |raw| raw["preset"] }
        Detection.candidates(worktree, Presets.all.reject { |preset| left_out.include?(preset.name) })
      end

      def self.stamps(worktree, globs)
        globs.flat_map { |glob| worktree.glob(glob) }.uniq.to_h { |path| [path, worktree.stamp(path)] }
      end
      private_class_method :stamps
    end
  end
end
