# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/evidence_fixtures"
require "digest"
require "fun_ci/evidence/presets"

# A preset is only as good as the output it was checked against, so every
# preset has a recorded failing run, the run is the one recorded, and what it
# is expected to pick out is a range of that run's own lines (why.md,
# "Fixtures"). A hash shows an edit; it doesn't stop one.
class TestEvidenceFixtures < Minitest::Test
  RANGE = /\Aoutput:(\d+)(?:-(\d+))?\z/

  def test_every_preset_has_a_recorded_run
    assert_empty FunCi::Evidence::Presets.all.map(&:name) - EvidenceFixtures.all.map(&:name)
  end

  def test_every_recorded_run_pins_a_preset
    assert_empty EvidenceFixtures.all.map(&:name) - FunCi::Evidence::Presets.all.map(&:name)
  end

  def test_every_recorded_output_is_the_one_its_meta_describes
    changed = EvidenceFixtures.all.reject { |fixture| Digest::SHA256.hexdigest(fixture.output) == fixture.meta["sha256"] }

    assert_empty changed.map(&:name)
  end

  def test_every_recording_says_how_it_was_made
    keys = %w[tool image command sha256 exit_status version script_commit]

    assert_empty(EvidenceFixtures.all.reject { |fixture| (keys - fixture.meta.keys).empty? }.map(&:name))
  end

  def test_every_recording_ran_in_an_image_pinned_by_digest
    assert_empty(EvidenceFixtures.all.reject { |fixture| fixture.meta["image"].include?("@sha256:") }.map(&:name))
  end

  def test_every_expected_excerpt_is_a_range_of_the_recorded_output
    assert_empty(EvidenceFixtures.all.flat_map { |fixture| outside(fixture) })
  end

  def test_every_signature_matches_its_own_tool_s_recorded_run
    silent = signed.reject { |preset| matches?(preset, fixture(preset.name)) }

    assert_empty silent.map(&:name)
  end

  # What notices a bad edit to a preset, which no mutation tool reads.
  def test_no_signature_matches_another_tool_s_recorded_run
    crossed = signed.product(EvidenceFixtures.all)
                    .select { |preset, run| preset.name != run.name && matches?(preset, run) }

    assert_empty(crossed.map { |preset, run| "#{preset.name} matches #{run.name}" })
  end

  private

  def signed = FunCi::Evidence::Presets.all.select(&:signature)
  def fixture(name) = EvidenceFixtures.all.find { |run| run.name == name }
  def matches?(preset, run) = run.output.lines.any? { |line| Regexp.new(preset.signature).match?(line.chomp) }

  def outside(fixture)
    fixture.expected.fetch("excerpts").reject { |location| within?(location, fixture.output.lines.size) }
           .map { |location| "#{fixture.name} #{location}" }
  end

  def within?(location, size)
    match = RANGE.match(location)
    return false unless match

    first = match[1].to_i
    last = (match[2] || match[1]).to_i
    first.between?(1, last) && last <= size
  end
end
