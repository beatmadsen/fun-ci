# frozen_string_literal: true

require_relative "project_detector"
require_relative "template_writer"
require_relative "lint_detection"
require_relative "agent_instructions"

module FunCi
  module Setup
    class Installer
      # Which stages run side by side, and so what each may touch (design.md,
      # Stages side by side).
      SIDE_BY_SIDE = ["lint.sh runs beside build.sh, so it reads the source alone.",
                      "Then fast.sh runs beside slow.sh, both on what build.sh built: have build.sh " \
                      "compile everything they need, test code included."].freeze

      def self.run(project_root:, stdout: $stdout)
        new(project_root: project_root, stdout: stdout).run
      end

      def initialize(project_root:, stdout:)
        @project_root = project_root
        @stdout = stdout
      end

      # A project set up for fun-ci, new or not, also tells agents what to do.
      def run
        code = set_up
        tell_agents if code.zero?
        code
      end

      private

      def set_up
        return report(".fun-ci/ already exists, so init left it as it is.", 0) if initialised?

        detected = ProjectDetector.new(Dir.children(@project_root)).detect
        return report("Could not detect project type. Create .fun-ci/ manually.", 1) if detected == :unknown

        write_templates(detected)
      end

      def tell_agents
        file = AgentInstructions.file_for(Dir.children(@project_root))
        path = File.join(@project_root, file)
        told = File.exist?(path) ? File.read(path) : ""
        merged = AgentInstructions.merged(told)
        return unless merged

        File.write(path, merged)
        @stdout.puts AgentInstructions.said(told, file)
      end

      def initialised?
        Dir.exist?(File.join(@project_root, ".fun-ci"))
      end

      def write_templates(detected)
        @stdout.puts "Detected: #{detected.to_s.tr("_", " ")}"
        TemplateWriter.new(detected, @project_root, lint_override: LintDetection.command(detected, @project_root)).write
        @stdout.puts "Created .fun-ci/ with template scripts.", *SIDE_BY_SIDE
        0
      end

      def report(message, exit_code)
        @stdout.puts message
        exit_code
      end
    end
  end
end
