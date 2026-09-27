# frozen_string_literal: true

require_relative "../findings"
require_relative "../../pipeline/test_report"

module FunCi
  module Evidence
    module Extractors
      # `junit-files`: the failures in the JUnit XML under `paths` that the
      # stage wrote, where a build tool keeps its own reports
      # (target/surefire-reports/*.xml, build/test-results/**/*.xml).
      class JunitFiles
        OPTIONS = { "paths" => :globs }.freeze
        REQUIRED = %w[paths].freeze

        def initialize(options)
          @options = options
        end

        def extract(context)
          written = globs.flat_map { |glob| context.worktree.glob(glob) }.uniq
                         .reject { |path| context.watched[path] == context.worktree.stamp(path) }
          Findings.new(failures: written.flat_map do |path|
            Pipeline::TestReport.junit(context.worktree.read(path)) || []
          end)
        end

        def globs = Array(@options["paths"])
      end
    end
  end
end
