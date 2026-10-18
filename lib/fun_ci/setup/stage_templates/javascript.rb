# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # JavaScript and TypeScript: Deno, Bun, and Node with its package managers.
    # Lint runs beside the build, which installs the packages, so it checks
    # the source alone: a linter that loads them, ESLint, goes in the build
    # after the install (EslintDetection). Deno's lint needs no packages.
    module StageTemplates
      SOURCES = "find . -name node_modules -prune -o -name .git -prune -o -type f"
      NODE_CHECK = "#{SOURCES} \\( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \\) -print | " \
                   'while read -r file; do node --check "$file" || exit 1; done'.freeze
      BUN_CHECK = "#{SOURCES} \\( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' " \
                  "-o -name '*.tsx' \\) -print | " \
                  'while read -r file; do bun build --no-bundle "$file" > /dev/null || exit 1; done'.freeze

      JAVASCRIPT = {
        deno: stages("deno lint", "deno check", "deno test", "deno task test:slow"),
        bun: stages(BUN_CHECK, "bun install", "bun test", "bun run test:slow"),
        node_pnpm: stages(NODE_CHECK, "pnpm install", "pnpm test", "pnpm run test:slow"),
        node_yarn: stages(NODE_CHECK, "yarn install", "yarn test", "yarn run test:slow"),
        node_npm: stages(NODE_CHECK, "npm install", "npm test", "npm run test:slow")
      }.freeze
    end
  end
end
