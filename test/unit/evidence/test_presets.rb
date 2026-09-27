# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/evidence_kit"
require_relative "../../support/evidence_fixtures"
require "fun_ci/evidence/catalog"
require "fun_ci/evidence/presets"

# Each preset picks out its tool's failures from a recorded failing run of
# that tool (acceptance-tests.md, AT-10.10; architecture.md, "Evidence of a failed stage").
class TestPresets < Minitest::Test
  include EvidenceKit

  EvidenceFixtures.all.each do |fixture|
    define_method("test_#{fixture.name.tr("-", "_")}_picks_out_the_excerpts_expected_of_its_recorded_run") do
      assert_equal fixture.expected.fetch("excerpts"), locations_found(fixture)
    end
  end

  EvidenceFixtures.all.select { |fixture| fixture.expected.key?("lines") }.each do |fixture|
    define_method("test_#{fixture.name.tr("-", "_")}_writes_the_lines_expected_of_its_recorded_run") do
      assert_equal fixture.expected.fetch("lines"), found(fixture).excerpts.first[:lines]
    end
  end

  def test_should_name_an_entry_for_a_preset_by_its_built_in_and_the_preset
    assert_equal "section:rspec", FunCi::Evidence::Catalog.entry({ "use" => "section", "preset" => "rspec" }).name
  end

  def test_should_refuse_a_preset_it_does_not_know
    error = assert_raises(FunCi::Evidence::Catalog::Refused) do
      FunCi::Evidence::Catalog.entry({ "use" => "section", "preset" => "nosuch" })
    end

    assert_equal "section has no preset 'nosuch'", error.message
  end

  def test_should_let_an_entry_s_own_options_take_the_place_of_its_preset_s
    entry = FunCi::Evidence::Catalog.entry({ "use" => "section", "preset" => "rspec", "title" => "Ours" })

    assert_equal "Ours", entry.extractor.extract(context(output: "Failures:\nx\n")).excerpts.first[:title]
  end

  private

  def locations_found(fixture) = found(fixture).excerpts.map { |excerpt| excerpt[:location] }

  def found(fixture)
    preset = FunCi::Evidence::Presets.fetch(fixture.name)
    entry = FunCi::Evidence::Catalog.entry({ "use" => preset.use, "preset" => fixture.name })
    entry.extractor.extract(context(output: fixture.output))
  end
end
