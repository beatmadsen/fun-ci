# frozen_string_literal: true

module FunCi
  module Setup
    # What every stack's stage scripts are made of.
    module StageTemplates
      def self.script(body) = "#!/bin/sh\n#{body}\n"

      def self.stages(lint, build, fast, slow)
        { "lint.sh" => lint, "build.sh" => build, "fast.sh" => fast, "slow.sh" => slow }.transform_values do |body|
          script(body)
        end
      end
    end
  end
end
