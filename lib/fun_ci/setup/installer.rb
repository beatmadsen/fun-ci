# frozen_string_literal: true

require_relative "project_detector"
require_relative "template_writer"
require_relative "lint_detection"
require_relative "eslint_detection"
require_relative "stage_templates"
require_relative "agent_instructions"

module FunCi
  module Setup
    class Installer
      # Which stages run side by side, and so what each may touch (design.md,
      # Stages side by side).
      SIDE_BY_SIDE = ["lint.sh runs beside build.sh, so it reads the source alone.",
                      "Then fast.sh runs beside slow.sh, both on what build.sh built: have build.sh " \
                      "compile everything they need, test code included."].freeze

      PLACEHOLDERS = "Could not detect the project type, so .fun-ci/ has placeholder scripts that pass and " \
                     "test nothing: put the project's own commands in them, or start again with --stack NAME."

      # stack: a name of ProjectDetector::STACKS to write in place of the one detected.
      def self.run(project_root:, stdout: $stdout, stack: nil)
        new(project_root: project_root, stdout: stdout, stack: stack).run
      end

      def initialize(project_root:, stdout:, stack:)
        @project_root = project_root
        @stdout = stdout
        @stack = stack
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

        stack = chosen_stack
        return unknown_stack if stack.nil?
        return write_placeholders if stack == :unknown

        write_templates(stack)
      end

      def chosen_stack
        return ProjectDetector.new(Dir.children(@project_root)).detect if @stack.nil?

        ProjectDetector::STACKS.keys.find { |stack| stack.to_s == @stack }
      end

      def unknown_stack
        report("fun-ci init: no stack named #{@stack}; the stacks are #{ProjectDetector::STACKS.keys.join(", ")}", 64)
      end

      def write_placeholders
        TemplateWriter.new(StageTemplates::PLACEHOLDERS, @project_root).write
        report(PLACEHOLDERS, 0)
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
        TemplateWriter.new(scripts_for(detected), @project_root).write
        @stdout.puts "Created .fun-ci/ with template scripts.", *SIDE_BY_SIDE
        0
      end

      def scripts_for(detected)
        StageTemplates.scripts(detected, lint_override: LintDetection.command(detected, @project_root),
                                         build_override: EslintDetection.build(detected, Dir.children(@project_root),
                                                                               package_json))
      end

      def package_json
        path = File.join(@project_root, "package.json")
        File.exist?(path) ? File.read(path) : "{}"
      end

      def report(message, exit_code)
        @stdout.puts message
        exit_code
      end
    end
  end
end
