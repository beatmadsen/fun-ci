# frozen_string_literal: true

module FunCi
  module Setup
    # What every stack's stage scripts are made of.
    module StageTemplates
      # What each stage runs beside, said where its script is edited (design.md,
      # Stages side by side).
      SIDE_BY_SIDE = {
        "lint.sh" => "Runs beside build.sh, so it reads the source alone.",
        "build.sh" => "Runs beside lint.sh; then fast.sh and slow.sh run side by side on what it builds.",
        "fast.sh" => "Runs beside slow.sh, on what build.sh built.",
        "slow.sh" => "Runs beside fast.sh, on what build.sh built."
      }.freeze

      def self.script(name, body) = "#!/bin/sh\n# #{SIDE_BY_SIDE.fetch(name)}\n#{body}\n"

      def self.stages(lint, build, fast, slow)
        { "lint.sh" => lint, "build.sh" => build, "fast.sh" => fast, "slow.sh" => slow }.to_h do |name, body|
          [name, script(name, body)]
        end
      end
    end
  end
end
