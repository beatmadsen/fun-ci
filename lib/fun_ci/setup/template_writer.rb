# frozen_string_literal: true

module FunCi
  module Setup
    # Writes a project's .fun-ci/ stage scripts, executable: scripts is { "lint.sh" => script, ... }.
    class TemplateWriter
      def initialize(scripts, target_dir)
        @scripts = scripts
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
