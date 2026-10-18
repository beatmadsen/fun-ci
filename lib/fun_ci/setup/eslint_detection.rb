# frozen_string_literal: true

require "json"
require_relative "stage_templates"

module FunCi
  module Setup
    # The build init writes for a JavaScript project that configures ESLint:
    # the template's install, then ESLint, which loads what the install put
    # in place, so it can't run in lint beside it (StageTemplates). nil keeps
    # the template's build.
    module EslintDetection
      RUNNERS = { node_npm: "npx eslint .", node_pnpm: "pnpm exec eslint .", node_yarn: "yarn eslint .",
                  bun: "bunx eslint ." }.freeze
      CONFIGS = %w[eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts
                   eslint.config.cts .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml
                   .eslintrc.yaml].freeze

      # names: the files at the project's top; package_json: its text.
      def self.build(stack, names, package_json)
        runner = RUNNERS[stack]
        return nil unless runner && configured?(names, package_json)

        "#{StageTemplates.scripts(stack)["build.sh"].lines.last.chomp} && #{runner}"
      end

      def self.configured?(names, package_json) = names.intersect?(CONFIGS) || in_package?(package_json)

      def self.in_package?(text)
        parsed = JSON.parse(text)
        parsed.is_a?(Hash) && parsed.key?("eslintConfig")
      rescue JSON::ParserError
        false
      end
      private_class_method :configured?, :in_package?
    end
  end
end
