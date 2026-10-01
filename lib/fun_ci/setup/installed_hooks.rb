# frozen_string_literal: true

require_relative "lfs_hook"

module FunCi
  module Setup
    # The post-commit and pre-push hooks git runs, as `fun-ci check` warns of
    # them: one that doesn't run fun-ci tests no commit, or lets a push
    # through without a verdict. `fun-ci install-hooks` writes either when it
    # is missing or git-lfs's own; another tool's has to call fun-ci itself.
    class InstalledHooks
      WHAT = { "post-commit" => "No commit is tested", "pre-push" => "No push waits for a verdict" }.freeze
      INSTALL = "Run `fun-ci install-hooks`"
      CALL = { "post-commit" => "`fun-ci trigger --background <commit> <branch>`",
               "pre-push" => "`fun-ci wait <commit> --need fast` for each commit pushed" }.freeze

      # hooks_dir: where git runs the project's hooks from; nil outside a git repository.
      def initialize(hooks_dir)
        @hooks_dir = hooks_dir
      end

      def warnings
        return [] unless @hooks_dir

        WHAT.keys.map { |type| warning(type, script(type)) }.compact
      end

      private

      def script(type)
        path = File.join(@hooks_dir, type)
        File.exist?(path) ? File.read(path) : ""
      end

      def warning(type, script)
        return nil if script.include?("fun-ci")
        return "#{WHAT[type]}: the #{type} hook doesn't run fun-ci. #{INSTALL}" if install_fixes?(script, type)

        "#{WHAT[type]}: the #{type} hook is another tool's and doesn't run fun-ci. Have it run #{CALL[type]}"
      end

      def install_fixes?(script, type) = script.empty? || LfsHook.stock?(script, type)
    end
  end
end
