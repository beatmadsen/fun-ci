# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/evidence_kit"
require_relative "../../support/arbitrary_output"
require_relative "../../support/fake_stage_dir"
require "fun_ci/evidence/catalog"
require "fun_ci/evidence/collector"
require "json"

# Properties of every built-in and of masking over arbitrary output (architecture.md,
# "Evidence of a failed stage"). Each run is seeded and says its seed when it fails.
class TestEvidenceProperties < Minitest::Test
  include EvidenceKit

  ENTRIES = [{ "use" => "grep", "patterns" => ["ERROR"], "context" => 2 },
             { "use" => "section", "preset" => "rspec" },
             { "use" => "json-log", "preset" => "logstash", "level" => "debug" },
             { "use" => "log-file", "path" => "log/*.log", "grep" => ["ERROR"] },
             { "use" => "junit-files", "paths" => ["reports/*.xml"] },
             { "use" => "process-tree" }].freeze

  def test_every_built_in_answers_findings_for_any_output
    seed = Random.new_seed
    output = ArbitraryOutput.new(Random.new(seed))
    found = Array.new(30) { ENTRIES.map { |raw| extracted(raw, output.text) } }.flatten

    assert(found.all?(FunCi::Evidence::Findings), "seed #{seed}")
  end

  def test_no_secret_survives_in_the_evidence_or_the_raw_output
    seed = Random.new_seed
    arbitrary = ArbitraryOutput.new(Random.new(seed))
    survivors = Array.new(30) { secret_left_in(arbitrary) }.compact

    assert_empty survivors, "seed #{seed}"
  end

  private

  def extracted(raw, text)
    context = context(output: text, files: { "log/a.log" => text, "reports/a.xml" => text }, pgid: 1,
                      processes: -> { [] })
    FunCi::Evidence::Catalog.entry(raw).extractor.extract(context)
  end

  # The secret, if it survived one collection of output holding it.
  def secret_left_in(arbitrary)
    secret = arbitrary.word(8 + arbitrary.piece.bytesize)
    output = [arbitrary.text(50), "ERROR #{secret}", arbitrary.text(50), secret, arbitrary.text(20)].join
    collector = collector({ "DEPLOY_TOKEN" => secret })
    kept = JSON.generate(collector.collect(output).to_h).b + collector.masked(output).b
    kept.include?(secret) ? secret : nil
  end

  def collector(environment)
    sources = FunCi::Evidence::Sources.new(stage: "fast", worktree: "/nowhere", stage_dir: FakeStageDir.new,
                                           environment: environment)
    settings = FunCi::Evidence::Settings.new({ "stages" => { "fast" => ENTRIES.first(3) } })
    FunCi::Evidence::Collector.new(sources, settings: settings, clock: -> { 0 })
  end
end
