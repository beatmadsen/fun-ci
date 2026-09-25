# frozen_string_literal: true

module FunCi
  module Setup
    class ProjectConfig
      REQUIRED_SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

      def initialize(project_root)
        @project_root = project_root
        @fun_ci_dir = File.join(project_root, ".fun-ci")
      end

      def folder_exists?
        Dir.exist?(@fun_ci_dir)
      end

      def validate
        return ["No .fun-ci/ folder found in #{@project_root}"] unless folder_exists?

        REQUIRED_SCRIPTS.flat_map { |script| script_errors(script) }
      end

      def script_path(stage)
        File.join(@fun_ci_dir, "#{stage}.sh")
      end

      private

      def script_errors(script)
        path = File.join(@fun_ci_dir, script)
        return [".fun-ci/#{script} is not found"] unless File.exist?(path)
        return [".fun-ci/#{script} is not executable"] unless File.executable?(path)

        []
      end
    end
  end
end
