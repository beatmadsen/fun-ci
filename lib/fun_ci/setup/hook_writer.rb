# frozen_string_literal: true

require "fileutils"
require_relative "hook_script"

module FunCi
  module Setup
    class HookWriter
      def self.run(project_root:, hook_type:, stdout: $stdout)
        new(project_root: project_root, hook_type: hook_type, stdout: stdout).run
      end

      def initialize(project_root:, hook_type:, stdout:)
        @project_root = project_root
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

      def git_repo?
        Dir.exist?(File.join(@project_root, ".git"))
      end

      def hook_path
        File.join(@project_root, ".git", "hooks", @hook_type)
      end

      def foreign_hook?
        File.exist?(hook_path) && !HookScript.managed?(File.read(hook_path))
      end

      def write_hook
        FileUtils.mkdir_p(File.join(@project_root, ".git", "hooks"))
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
