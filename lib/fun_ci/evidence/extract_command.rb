# frozen_string_literal: true

require "json"
require "tmpdir"
require_relative "extract_options"
require_relative "saved_run"
require_relative "collector"
require_relative "command_runner"
require_relative "worktree"
require_relative "../agent/stage_summary"
require_relative "../agent/evidence_text"
require_relative "../agent/report_stage"

module FunCi
  module Evidence
    # `fun-ci extract STAGE --output FILE` (acceptance-tests.md, AT-10.16):
    # runs a stage's extractors against a saved output, with the current
    # directory as the worktree, and prints what `why` would print, touching
    # no database, so a project can try an extractor without a commit.
    class ExtractCommand
      NO_START = { name: "start sizes",
                   value: "none, so files are read whole and every watched file counts as changed" }.freeze
      NO_GROUP = { name: "process group", value: "none, so entries with on: overrun don't run" }.freeze

      def initialize(dir, io)
        @dir = dir
        @io = io
      end

      def run(args)
        options = ExtractOptions.parse(args)
        document = Dir.mktmpdir("fun-ci-extract") { |scratch| collect(options, scratch) }
        options.json ? print_json(options, document) : print_text(options, document)
        0
      rescue ExtractOptions::Invalid => e
        @io.stderr.puts "fun-ci extract: #{e.message}"
        64
      end

      private

      def collect(options, scratch)
        saved = SavedRun.new(options.reports && File.expand_path(options.reports, @dir), scratch)
        sources = Sources.new(stage: options.stage, worktree: @dir, reports: saved, environment: ENV.to_h)
        collector = Collector.new(sources, settings: Settings.load(File.join(@dir, ".fun-ci", "config")),
                                           commands: CommandRunner.new(dir: @dir, env: saved.env, scratch: scratch))
        noted(collector.collect(output(options), outcome(options)), options)
      end

      def output(options) = Worktree.new(@dir).read(options.output)
      def state(options) = options.timed_out ? "over_budget" : "failed"

      def outcome(options)
        Outcome.new(state: state(options), exit_status: options.timed_out ? nil : options.exit_status)
      end

      def noted(document, options)
        notes = [NO_START, *(options.timed_out ? [NO_GROUP] : [])]
        notes = notes.map { |fact| fact.merge(extractor: "fun-ci extract") }
        document.with(facts: notes + document.facts)
      end

      def print_text(options, document)
        stage = Agent::RunReport::Stage.new(name: options.stage, state: state(options), seconds: nil,
                                            exit: Agent::RunReport::Exit.new(exit_status: outcome(options).exit_status,
                                                                             signal: nil, budget: nil))
        [Agent::StageSummary.line(stage), *Agent::EvidenceText.lines(document)].each { |line| @io.stdout.puts line }
      end

      def print_json(options, document)
        @io.stdout.puts JSON.generate({ schema: 1, stage: options.stage, state: state(options),
                                        exit_status: outcome(options).exit_status, evidence: document.to_h })
      end
    end
  end
end
