# frozen_string_literal: true

module FunCi
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
      errors = []

      unless folder_exists?
        errors << "No .fun-ci/ folder found in #{@project_root}"
        return errors
      end

      REQUIRED_SCRIPTS.each do |script|
        path = File.join(@fun_ci_dir, script)
        if !File.exist?(path)
          errors << ".fun-ci/#{script} is not found"
        elsif !File.executable?(path)
          errors << ".fun-ci/#{script} is not executable"
        end
      end

      errors
    end

    def script_path(stage)
      File.join(@fun_ci_dir, "#{stage}.sh")
    end
  end
end
