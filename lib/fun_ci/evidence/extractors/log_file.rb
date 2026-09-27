# frozen_string_literal: true

require_relative "../findings"
require_relative "../source"
require_relative "grep"
require_relative "section"
require_relative "last_lines"

module FunCi
  module Evidence
    module Extractors
      # `log-file`: what the stage wrote to the files under `path`, read from
      # the size each had when it started; whole, for one it created, or one
      # rewritten (no longer, or a new inode), which the fact `truncated`
      # names. Filtered by `grep` or by a section from `start`, when given,
      # else its last `lines`.
      class LogFile
        OPTIONS = { "path" => :path, "grep" => :patterns, "context" => :count, "start" => :patterns,
                    "end" => :patterns, "lines" => :count }.freeze
        REQUIRED = %w[path].freeze
        LINES = 200

        def initialize(options)
          @options = options
        end

        def extract(context)
          changed = context.worktree.glob(@options["path"]).reject { |path| unchanged?(context, path) }
          found = changed.map { |path| written(context, path) }
          Findings.new(facts: changed.select { |path| rewritten?(context, path) }.map { |path| truncated(path) },
                       excerpts: found.flat_map(&:excerpts))
        end

        private

        def truncated(path) = { name: "truncated", value: path }
        def unchanged?(context, path) = context.watched[path] == context.worktree.stamp(path)

        # Changed without growing, or replaced by another file.
        def rewritten?(context, path)
          before = context.watched[path]
          now = context.worktree.stamp(path)
          !before.nil? && (now.size <= before.size || now.inode != before.inode)
        end

        def written(context, path)
          from = rewritten?(context, path) ? 0 : context.watched[path]&.size.to_i
          source = Source.of(path, context.worktree.read(path, from: from),
                             skipped: context.worktree.lines_before(path, from))
          filter.found_in(source, context.deadline)
        end

        def filter
          return Grep.new(@options.slice("context").merge("patterns" => @options["grep"])) if @options["grep"]
          return Section.new(@options.slice("start", "end", "lines")) if @options["start"]

          LastLines.new(@options.fetch("lines", LINES))
        end
      end
    end
  end
end
