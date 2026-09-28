# frozen_string_literal: true

require "fileutils"
require_relative "hook_script"

module FunCi
  module Setup
    # Writes a hook into `hooks_dir`, where git runs the project's hooks
    # from (GitHooks.dir); nil outside a git repository.
    class HookWriter
      def self.run(hooks_dir:, hook_type:, stdout: $stdout)
        new(hooks_dir: hooks_dir, hook_type: hook_type, stdout: stdout).run
      end

      def initialize(hooks_dir:, hook_type:, stdout:)
        @hooks_dir = hooks_dir
        @hook_type = hook_type
        @stdout = stdout
      end

      def run
        return reject("Not a git repository: no .git/ found.") unless git_repo?
        return reject("Unknown hook type: #{@hook_type}") unless HookScript.types.include?(@hook_type)
        return skip("Hook #{@hook_type} already exists from another tool, so it was left alone.") if foreign_hook?

        write_hook
        @stdout.puts "Installed #{@hook_type} hook."
        0
      end

      private

      def git_repo? = !@hooks_dir.nil?
      def hook_path = File.join(@hooks_dir, @hook_type)

      def foreign_hook?
        File.exist?(hook_path) && !HookScript.managed?(File.read(hook_path))
      end

      def write_hook
        FileUtils.mkdir_p(@hooks_dir)
        File.write(hook_path, HookScript.for(@hook_type))
        File.chmod(0o755, hook_path)
      end

      def reject(message)
        @stdout.puts message
        1
      end

      def skip(message)
        @stdout.puts message
        0
      end
    end
  end
end
