# frozen_string_literal: true

require "fileutils"
require_relative "hook_script"
require_relative "lfs_hook"

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

        lfs = lfs?
        write_hook(lfs ? LfsHook.script(@hook_type) : HookScript.for(@hook_type))
        @stdout.puts "Installed #{@hook_type} hook#{", which runs git-lfs's too" if lfs}."
        0
      end

      private

      def git_repo? = !@hooks_dir.nil?
      def hook_path = File.join(@hooks_dir, @hook_type)

      def existing = File.exist?(hook_path) ? File.read(hook_path) : ""

      # git-lfs's own hook is not left alone: fun-ci's runs it.
      def foreign_hook?
        script = existing
        !script.empty? && !HookScript.managed?(script) && !LfsHook.stock?(script, @hook_type)
      end

      def lfs? = LfsHook.runs_lfs?(existing, @hook_type)

      def write_hook(script)
        FileUtils.mkdir_p(@hooks_dir)
        File.write(hook_path, script)
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
