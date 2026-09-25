# frozen_string_literal: true

require_relative "hook_script"

module FunCi
  module Setup
    # fun-ci 1.x ran the background pipeline from a pre-commit hook, before
    # the commit existed. The hook fun-ci wrote goes on upgrade; one someone
    # wrote by hand that still calls fun-ci is warned about, never touched.
    class LegacyHooks
      WARNING = ".git/hooks/pre-commit calls fun-ci, which now runs after the commit: " \
                "take fun-ci out of it and run `fun-ci install-hooks`"

      def initialize(project_root)
        @hook = File.join(project_root, ".git", "hooks", "pre-commit")
      end

      def remove(stdout)
        return unless File.exist?(@hook) && HookScript.managed?(File.read(@hook))

        File.delete(@hook)
        stdout.puts "Removed fun-ci's 1.x pre-commit hook; the background pipeline now runs from post-commit."
      end

      def warnings
        return [] unless File.exist?(@hook)

        script = File.read(@hook)
        !HookScript.managed?(script) && script.include?("fun-ci") ? [WARNING] : []
      end
    end
  end
end
