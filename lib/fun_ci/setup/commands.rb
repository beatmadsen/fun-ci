# frozen_string_literal: true

require_relative "installer"
require_relative "hook_writer"
require_relative "git_hooks"
require_relative "setup_checker"
require_relative "legacy_hooks"

module FunCi
  module Setup
    # `fun-ci init`, `install-hooks` and `check`, in the project directory.
    # `hooks_dir` answers where git runs a project's hooks from.
    class Commands
      def initialize(project_root, stdout, hooks_dir: GitHooks.method(:dir))
        @project_root = project_root
        @stdout = stdout
        @hooks_dir = hooks_dir
      end

      def init(args)
        code = Installer.run(project_root: @project_root, stdout: @stdout)
        return code if !code.zero? || !args.include?("--everything")

        code = install_hooks([])
        return code unless code.zero?

        check([])
      end

      def install_hooks(args)
        LegacyHooks.new(@project_root).remove(@stdout)
        install(args.any? ? [args.first] : HookScript.types)
      end

      def check(_args) = SetupChecker.run(project_root: @project_root, stdout: @stdout)

      private

      def install(types)
        hooks_dir = @hooks_dir.call(@project_root)
        types.each do |type|
          code = HookWriter.run(hooks_dir: hooks_dir, hook_type: type, stdout: @stdout)
          return code unless code.zero?
        end
        0
      end
    end
  end
end
