# frozen_string_literal: true

require_relative "project_detector"
require_relative "template_writer"

module FunCi
  class Installer
    def self.run(project_root:, stdout: $stdout, stderr: $stderr)
      new(project_root: project_root, stdout: stdout).run
    end

    def initialize(project_root:, stdout:)
      @project_root = project_root
      @stdout = stdout
    end

    def run
      if Dir.exist?(File.join(@project_root, ".fun-ci"))
        @stdout.puts ".fun-ci/ already exists. Remove it first to re-initialize."
        return 1
      end

      filenames = Dir.children(@project_root)
      detected = ProjectDetector.new(filenames).detect

      @stdout.puts "Detected: #{detected.to_s.tr("_", " ")}"

      TemplateWriter.new(detected, @project_root).write

      @stdout.puts "Created .fun-ci/ with template scripts."
      0
    end
  end
end
