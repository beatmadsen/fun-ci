# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # JavaScript and TypeScript: Deno, Bun, and Node with its package managers.
    module StageTemplates
      JAVASCRIPT = {
        deno: stages("deno lint", "deno check", "deno test", "deno task test:slow"),
        bun: stages("bunx eslint .", "bun install", "bun test", "bun run test:slow"),
        node_pnpm: stages("pnpm exec eslint .", "pnpm install", "pnpm test", "pnpm run test:slow"),
        node_yarn: stages("yarn eslint .", "yarn install", "yarn test", "yarn run test:slow"),
        node_npm: stages("npx eslint .", "npm install", "npm test", "npm run test:slow")
      }.freeze
    end
  end
end
