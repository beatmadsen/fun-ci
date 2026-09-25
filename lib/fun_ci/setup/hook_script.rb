# frozen_string_literal: true

module FunCi
  module Setup
    # The script fun-ci writes into each git hook it manages.
    module HookScript
      MARKER = "# fun-ci-managed-hook"

      COMMANDS = {
        "post-commit" => "fun-ci trigger --background",
        "pre-push" => "fun-ci trigger"
      }.freeze

      TEMPLATE = <<~SH.freeze
        #!/bin/sh
        #{MARKER}
        COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "0000000000000000000000000000000000000000")
        BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        %<command>s "$COMMIT" "$BRANCH"
      SH

      def self.types = COMMANDS.keys
      def self.for(hook_type) = format(TEMPLATE, command: COMMANDS.fetch(hook_type))
      def self.managed?(script) = script.include?(MARKER)
    end
  end
end
