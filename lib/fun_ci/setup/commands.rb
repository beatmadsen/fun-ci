# frozen_string_literal: true

require_relative "installer"
require_relative "hook_writer"
require_relative "setup_checker"
require_relative "legacy_hooks"

module FunCi
  module Setup
    # `fun-ci init`, `install-hooks` and `check`, in the project directory.
    class Commands
      def initialize(project_root, stdout)
        @project_root = project_root
        @stdout = stdout
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
        types.each do |type|
          code = HookWriter.run(project_root: @project_root, hook_type: type, stdout: @stdout)
          return code unless code.zero?
        end
        0
      end
    end
  end
end
