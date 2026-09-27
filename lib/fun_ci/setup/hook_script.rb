# frozen_string_literal: true

module FunCi
  module Setup
    # The script fun-ci writes into each git hook it manages.
    module HookScript
      MARKER = "# fun-ci-managed-hook"
      NULL_SHA = "0" * 40

      GUARD = <<~SH.freeze
        #!/bin/sh
        #{MARKER}
        if ! command -v fun-ci >/dev/null 2>&1; then
          echo "fun-ci is not installed or not on PATH, so this runs without CI. Install it with: gem install fun_ci" >&2
          exit 0
        fi
      SH

      # After a commit: the commit just made, in the background.
      POST_COMMIT = <<~SH.freeze
        COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "#{NULL_SHA}")
        BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        fun-ci trigger --background "$COMMIT" "$BRANCH"
      SH

      # Before a push: the fast verdict of each commit git says it pushes
      # (acceptance-tests.md, AT-9.13). A deleted ref pushes the null SHA, and
      # exit 5 is a project not set up for fun-ci, which pushes without CI.
      PRE_PUSH = <<~SH.freeze
        status=0
        while read -r local_ref local_sha remote_ref remote_sha; do
          [ "$local_sha" = "#{NULL_SHA}" ] && continue
          fun-ci wait "$local_sha" --need fast
          code=$?
          [ "$code" -eq 0 ] || [ "$code" -eq 5 ] || status=1
        done
        exit $status
      SH

      BODIES = { "post-commit" => POST_COMMIT, "pre-push" => PRE_PUSH }.freeze

      def self.types = BODIES.keys
      def self.for(hook_type) = GUARD + BODIES.fetch(hook_type)
      def self.managed?(script) = script.include?(MARKER)
    end
  end
end
