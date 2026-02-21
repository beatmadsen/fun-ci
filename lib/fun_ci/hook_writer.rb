# frozen_string_literal: true

require "fileutils"

module FunCi
  class HookWriter
    ALLOWED_HOOKS = %w[pre-commit pre-push].freeze
    MARKER = "# fun-ci-managed-hook"

    HOOK_COMMANDS = {
      "pre-commit" => "fun-ci trigger --no-validate",
      "pre-push" => "fun-ci trigger"
    }.freeze

    HOOK_TEMPLATE = <<~SH
      #!/bin/sh
      #{MARKER}
      COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "0000000000000000000000000000000000000000")
      BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
      %<command>s "$COMMIT" "$BRANCH"
    SH

    def self.run(project_root:, hook_type:, stdout: $stdout)
      new(project_root: project_root, hook_type: hook_type, stdout: stdout).run
    end

    def initialize(project_root:, hook_type:, stdout:)
      @project_root = project_root
      @hook_type = hook_type
      @stdout = stdout
    end

    def run
      return reject("Not a git repository — no .git/ found.") unless git_repo?
      return reject("Unknown hook type: #{@hook_type}") unless ALLOWED_HOOKS.include?(@hook_type)
      return reject("Hook #{@hook_type} already exists from another tool.") if foreign_hook?

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
      File.exist?(hook_path) && !File.read(hook_path).include?(MARKER)
    end

    def write_hook
      FileUtils.mkdir_p(File.join(@project_root, ".git", "hooks"))
      File.write(hook_path, format(HOOK_TEMPLATE, command: HOOK_COMMANDS[@hook_type]))
      File.chmod(0o755, hook_path)
    end

    def reject(message)
      @stdout.puts message
      1
    end
  end
end
