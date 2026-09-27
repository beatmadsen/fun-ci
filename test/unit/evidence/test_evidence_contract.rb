# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/evidence_kit"
require "fun_ci/evidence/context_document"
require "fun_ci/evidence/command_output"
require "json"

# The documents a project's extractor and fun-ci exchange, held to the
# fixtures in contract/evidence/ (why.md, "Your own extractor").
class TestEvidenceContract < Minitest::Test
  include EvidenceKit

  CONTRACT = File.expand_path("../../../contract/evidence", __dir__)
  ABOUT = FunCi::Evidence::About.new(
    stage: "fast", state: "failed", exit_status: 1, signal: nil, seconds: 8.4, budget: 10, alongside: ["slow"],
    commit: { sha: "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a", branch: "main" },
    worktree: "/repo/.git/fun-ci/worktrees/slot-1", started_at: "2026-09-27T14:02:11.402Z",
    output: "/state/fun-ci/stages/4242-abc/output.log", reports: "/state/fun-ci/stages/4242-abc/reports"
  )

  FILES = { "build/test-results/test/TEST-FooTest.xml" => "<x/>", "log/test.log" => "a" * 1_048_576 }.freeze
  WATCH = ["build/test-results/test/*.xml", "log/*.log"].freeze

  def test_should_write_the_context_the_fixture_publishes
    context = context(files: FILES, watched: { "log/test.log" => stamp(1_048_576) })
    document = FunCi::Evidence::ContextDocument.for(ABOUT, context, watch: WATCH, options: { "module" => "core" })

    assert_equal fixture("context.json"), JSON.parse(JSON.generate(document))
  end

  def test_should_read_a_document_with_fields_it_does_not_know
    found = FunCi::Evidence::CommandOutput.json(File.read(File.join(CONTRACT, "unknown-fields.json")))

    assert_equal [{ name: "module", value: "core" }], found.facts
  end

  def test_should_refuse_a_document_of_a_higher_schema
    assert_raises(FunCi::Evidence::Problem) do
      FunCi::Evidence::CommandOutput.json(File.read(File.join(CONTRACT, "higher-schema.json")))
    end
  end

  private

  def fixture(name) = JSON.parse(File.read(File.join(CONTRACT, name)))
end
