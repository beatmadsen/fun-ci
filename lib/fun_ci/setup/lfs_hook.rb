# frozen_string_literal: true

require_relative "hook_script"

module FunCi
  module Setup
    # git-lfs's own post-commit and pre-push hooks, as `git lfs install`
    # writes them, and the hook fun-ci writes in their place, which runs
    # fun-ci's, then git-lfs's. A push reads its ref list from git once, so
    # the pre-push hook keeps it in a file and gives it to both.
    module LfsHook
      GUARD = %r{\Acommand -v git-lfs >/dev/null 2>&1 \|\| \{.*; exit 2; \}\z}
      MISSING = %(command -v git-lfs >/dev/null 2>&1 || { echo "This repository is configured for Git LFS ) +
                %(but 'git-lfs' was not found on your path." >&2; exit 2; })

      RUN = {
        "post-commit" => "if #{HookScript::INSTALLED}; then fun_ci; else #{HookScript::NOT_INSTALLED}; fi\n",
        "pre-push" => %(if #{HookScript::INSTALLED}; then fun_ci < "$refs" || exit 1; ) +
                      "else #{HookScript::NOT_INSTALLED}; fi\n"
      }.freeze

      KEEP_REFS = { "post-commit" => "", "pre-push" => <<~SH }.freeze
        refs=$(mktemp) || exit 1
        trap 'rm -f "$refs"' EXIT
        cat > "$refs"
      SH

      FUN_CI = { "post-commit" => HookScript::POST_COMMIT, "pre-push" => "#{HookScript::PRE_PUSH_WAITS}return $status\n" }
               .freeze
      LFS_INPUT = { "post-commit" => "", "pre-push" => %( < "$refs") }.freeze

      # Whether `script` is the hook `git lfs install` writes for `hook_type`
      # and nothing more.
      def self.stock?(script, hook_type)
        lines = script.lines(chomp: true).reject { |line| line.strip.empty? }
        lines.size == 3 && lines.first == "#!/bin/sh" && GUARD.match?(lines[1]) && lines.last == call(hook_type)
      end

      def self.runs_lfs?(script, hook_type) = script.include?(call(hook_type))

      def self.script(hook_type)
        "#!/bin/sh\n#{HookScript::MARKER}\n# fun-ci's #{hook_type} hook, then git-lfs's, which it replaced.\n" \
          "#{KEEP_REFS.fetch(hook_type)}fun_ci() {\n#{FUN_CI.fetch(hook_type)}}\n" \
          "#{RUN.fetch(hook_type)}#{MISSING}\n#{call(hook_type)}#{LFS_INPUT.fetch(hook_type)}\n"
      end

      def self.call(hook_type) = %(git lfs #{hook_type} "$@")
    end
  end
end
