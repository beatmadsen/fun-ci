# frozen_string_literal: true

module FunCi
  module Console
    # Where the renderer binary is (architecture.md, Distribution): the one
    # FUN_CI_RENDERER names, else the one a platform gem bundles in libexec/,
    # else the first on PATH.
    class RendererLookup
      class Missing < StandardError; end

      NAME = "fun-ci-renderer"
      HOW_TO_GET_ONE = "fun-ci console needs its renderer, #{NAME}, and this installation has none. " \
                       "Install it with `cargo install #{NAME}`, or set FUN_CI_RENDERER to its path.".freeze

      # The installed gem's libexec/, where a platform gem puts the renderer.
      LIBEXEC = File.expand_path("../../../libexec", __dir__)

      def self.default = new(env: ENV, libexec: LIBEXEC, executable: method(:runnable?))

      # Whether `path` is a file this user may run.
      def self.runnable?(path) = File.file?(path) && File.executable?(path)

      def initialize(env:, libexec:, executable:)
        @env = env
        @libexec = libexec
        @executable = executable
      end

      # The renderer's path. Raises Missing, saying how to get one, if none is found.
      def path
        named = @env["FUN_CI_RENDERER"].to_s
        return runnable(named) unless named.empty?

        candidates.find { |candidate| @executable.call(candidate) } || raise(Missing, HOW_TO_GET_ONE)
      end

      private

      def runnable(named)
        return named if @executable.call(named)

        raise Missing, "FUN_CI_RENDERER names #{named}, which is not a program fun-ci can run."
      end

      def candidates
        on_path = @env.fetch("PATH", "").split(File::PATH_SEPARATOR).reject(&:empty?)
        [@libexec, *on_path].map { |dir| File.join(dir, NAME) }
      end
    end
  end
end
