# frozen_string_literal: true

require_relative "sources"
require_relative "document"
require_relative "masking"
require_relative "settings"
require_relative "context"
require_relative "deadline"
require_relative "worktree"
require_relative "extraction"
require_relative "findings"
require_relative "../persistence/output_tail"

module FunCi
  module Evidence
    # Picks out what fun-ci keeps about a stage that failed (why.md, "How it
    # fits together"): the reported failures, then the entries configured for
    # the stage within the budget, then the output's last lines, all masked.
    class Collector
      MONOTONIC = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

      def initialize(sources, settings: Settings.new(nil), clock: MONOTONIC)
        @sources = sources
        @settings = settings
        @clock = clock
      end

      # alongside: the other stages that shared the slot while this one ran.
      def collect(output, alongside: [])
        result = Extraction.new(context(output), @settings.budget).run(configured)
        parts = [["fun-ci", own_facts(alongside)], ["test-reports", reported], *result.parts,
                 ["output-tail", tail(output)]]
        masking.document(Document.assemble(parts, problems: result.problems, chosen: result.chosen))
      end

      # The raw output, masked as the evidence is.
      def masked(output) = masking.mask(output)

      private

      def context(output)
        Context.new(stage: @sources.stage, output: output, worktree: Worktree.new(@sources.worktree),
                    deadline: Deadline.after(@clock, @settings.budget), watched: @sources.watched)
      end

      def own_facts(alongside)
        Findings.new(facts: alongside.empty? ? [] : [{ name: "alongside", value: alongside.join(", ") }])
      end

      def configured = @settings.entries(@sources.stage).map { |raw| [raw, "configured"] }
      def reported = Findings.new(failures: @sources.reports.failures)

      def tail(output)
        text = Persistence::OutputTail.of(output, mask: masking.method(:mask))
        Findings.new(excerpts: [{ title: Document::TAIL_TITLE, location: "output", lines: text.lines(chomp: true) }])
      end

      def masking
        return Masking.none unless @settings.masking?

        Masking.new(@sources.environment, patterns: @settings.mask_patterns)
      end
    end
  end
end
