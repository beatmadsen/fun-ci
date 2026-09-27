# frozen_string_literal: true

require_relative "sources"
require_relative "document"
require_relative "masking"
require_relative "settings"
require_relative "extraction"
require_relative "findings"
require_relative "outcome"
require_relative "stage_context"
require_relative "detection"
require_relative "source"
require_relative "caps"
require_relative "../persistence/output_tail"

module FunCi
  module Evidence
    # Picks out what fun-ci keeps about a stage that failed (why.md, "How it
    # fits together"): for an overrun, what process-tree and the entries for
    # an overrun found before the kill; the reported failures; the entries
    # configured for the stage, within the budget; then the output's last
    # lines; all masked.
    class Collector
      MONOTONIC = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      FAILED = Outcome.new(state: "failed")
      # How long past its budget a stage runs while its overrun is looked at.
      GRACE = 2
      NOTHING = Extraction::Result.new(parts: [], problems: [], chosen: [])

      # commands: runs a project's own extractors (a CommandRunner).
      def initialize(sources, settings: Settings.new(nil), clock: MONOTONIC, commands: nil)
        @sources = sources
        @settings = settings
        @contexts = StageContext.new(sources, clock, commands)
      end

      def collect(output, outcome = FAILED)
        result = extracted(output, outcome)
        overrun = outcome.overrun || NOTHING
        parts = [["fun-ci", own_facts(outcome.alongside)], *overrun.parts, ["test-reports", reported], *result.parts,
                 ["output-tail", tail(output)]]
        Caps.new.apply(masking.document(assemble(parts, [overrun, result])))
      end

      # What a stage over budget was doing, looked at before the kill.
      def before_kill(pgid)
        Extraction.new(@contexts.before_kill(pgid, GRACE), GRACE)
                  .run([[{ "use" => "process-tree" }, "overrun"], *entries("overrun")])
      end

      # The raw output, masked as the evidence is.
      def masked(output) = masking.mask(output)

      private

      # The configured entries, then the detected presets, within the budget.
      def extracted(output, outcome)
        context = @contexts.after(output, outcome, @settings.budget)
        Extraction.new(context, @settings.budget).run(entries(nil) + detected(output, context.deadline))
      end

      # The candidates' presets whose signatures the output matched, or that have none.
      def detected(output, deadline)
        Detection.chosen(Source.of("output", output).lines, @sources.candidates, deadline).map do |found|
          [{ "use" => found.preset.use, "preset" => found.preset.name }, found.because]
        end
      end

      def assemble(parts, results)
        Document.assemble(parts, problems: results.flat_map(&:problems), chosen: results.flat_map(&:chosen))
      end

      # The stage's entries that run on `on`: nil, when it fails, or "overrun".
      def entries(on)
        @settings.entries(@sources.stage).select { |raw| on_of(raw) == on }.map { |raw| [raw, "configured"] }
      end

      def on_of(raw) = raw.is_a?(Hash) ? raw["on"] : nil

      def own_facts(alongside)
        Findings.new(facts: alongside.empty? ? [] : [{ name: "alongside", value: alongside.join(", ") }])
      end

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
