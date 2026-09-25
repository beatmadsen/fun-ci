# frozen_string_literal: true

require_relative "stage_templates"

module FunCi
  module Setup
    # Writes a project's .fun-ci/ stage scripts, executable.
    class TemplateWriter
      def initialize(template_id, target_dir, lint_override: nil)
        @scripts = StageTemplates.scripts(template_id, lint_override: lint_override)
        @target_dir = target_dir
      end

      def write
        fun_ci_dir = File.join(@target_dir, ".fun-ci")
        Dir.mkdir(fun_ci_dir)
        @scripts.each { |name, content| write_script(File.join(fun_ci_dir, name), content) }
      end

      private

      def write_script(path, content)
        File.write(path, content)
        File.chmod(0o755, path)
      end
    end
  end
end
