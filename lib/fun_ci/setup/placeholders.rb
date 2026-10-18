# frozen_string_literal: true

require_relative "stage_templates"

module FunCi
  module Setup
    # The stage scripts in .fun-ci/ that are still init's placeholders, as
    # `fun-ci check`'s warnings.
    class Placeholders
      STAGES = %w[lint build fast slow].freeze

      def initialize(project_root)
        @dir = File.join(project_root, ".fun-ci")
      end

      def warnings = STAGES.select { |stage| placeholder?(stage) }.map { |stage| warning(stage) }

      private

      def placeholder?(stage)
        path = File.join(@dir, "#{stage}.sh")
        File.file?(path) && File.read(path).include?(StageTemplates::MARKER)
      end

      def warning(stage)
        ".fun-ci/#{stage}.sh is init's placeholder, so the #{stage} stage tests nothing: put the project's own in it"
      end
    end
  end
end
