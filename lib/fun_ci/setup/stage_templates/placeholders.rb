# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # The scripts `fun-ci init` writes where it knows no stack: each passes,
    # says it tests nothing, and carries MARKER, by which `fun-ci check` warns
    # of it until the project's own command takes its place.
    module StageTemplates
      MARKER = "# fun-ci placeholder"

      def self.placeholder(stage)
        "#{MARKER}: init knew no stack here, so put the project's #{stage} in place of this.\n" \
          "echo \"fun-ci: .fun-ci/#{stage}.sh is init's placeholder and tests nothing\""
      end

      PLACEHOLDERS = stages(*%w[lint build fast slow].map { |stage| placeholder(stage) }).freeze
    end
  end
end
