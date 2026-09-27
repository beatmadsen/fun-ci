# frozen_string_literal: true

require_relative "about"

module FunCi
  module Evidence
    # The context a project's command reads on stdin (why.md, "Your own
    # extractor"). Fields once published keep their names; a change that
    # isn't additive bumps SCHEMA.
    module ContextDocument
      SCHEMA = 1

      # watch: the entry's globs; options: whatever else the entry said.
      def self.for(about, context, watch:, options:)
        paths = watch.flat_map { |glob| context.worktree.glob(glob) }.uniq.sort
        { schema: SCHEMA, **about.to_h, changed: changed(paths, context), watched: watched(paths, context),
          options: options }
      end

      def self.changed(paths, context) = paths.reject { |path| context.watched[path] == context.worktree.stamp(path) }

      def self.watched(paths, context)
        existed = paths.select { |path| context.watched.key?(path) }
        existed.map { |path| { path: path, offset: context.watched[path].size } }
      end
      private_class_method :changed, :watched
    end
  end
end
