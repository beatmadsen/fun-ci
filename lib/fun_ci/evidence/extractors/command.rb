# frozen_string_literal: true

require "json"
require_relative "../command_output"
require_relative "../context_document"
require_relative "../problem"

module FunCi
  module Evidence
    module Extractors
      # A project's own extractor, a `run:` entry: the command, run in the
      # worktree with what is left of the budget, reads the context on stdin
      # and prints evidence as text or, with `format: json`, as a document
      # (why.md, "Your own extractor"). `watch` names the files it is told
      # about; whatever else the entry says is passed on as `options`.
      class Command
        OWN = %w[run format watch].freeze
        STDERR_LINES = 20

        def initialize(options)
          @options = options
        end

        def extract(context)
          ran = context.commands.call(@options["run"], stdin: JSON.generate(document(context)),
                                                       seconds: context.deadline.left)
          refuse(ran)
          return CommandOutput.json(ran.stdout) if @options["format"] == "json"

          CommandOutput.text(@options["run"], ran.stdout)
        end

        private

        def document(context)
          ContextDocument.for(context.about, context, watch: Array(@options["watch"]), options: @options.except(*OWN))
        end

        def refuse(ran)
          raise Problem, "killed: still running when the evidence budget ran out" if ran.killed == :budget
          raise Problem, "killed: printed more than 256 KB" if ran.killed == :overflow
          raise Problem, "exited #{ran.exit_status}: #{last_lines(ran.stderr)}" unless ran.exit_status.zero?
        end

        def last_lines(stderr) = stderr.lines(chomp: true).last(STDERR_LINES).join("\n")
      end
    end
  end
end
