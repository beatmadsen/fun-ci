# frozen_string_literal: true

require_relative "stage_templates/managed"
require_relative "stage_templates/native"
require_relative "stage_templates/scripting"
require_relative "stage_templates/javascript"

module FunCi
  module Setup
    # The stage scripts `fun-ci init` writes, per kind of project (AT-10.21).
    # Test stages run the fast suite without the tests the tool's convention
    # marks slow, and the slow suite with only those; where the tool has no
    # such convention, the slow suite is a `test:slow` script (`test-slow`,
    # for make).
    module StageTemplates
      TEMPLATES = [MANAGED, NATIVE, SCRIPTING, JAVASCRIPT].reduce(:merge).freeze

      # { "lint.sh" => script, ... }; +lint_override+ replaces the lint command.
      def self.scripts(template_id, lint_override: nil)
        scripts = TEMPLATES.fetch(template_id)
        lint_override ? scripts.merge("lint.sh" => script(lint_override)) : scripts
      end
    end
  end
end
