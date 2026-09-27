# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/evidence_kit"
require "fun_ci/evidence/detection"

# Which presets run (architecture.md, "Evidence of a failed stage"): those whose marker files
# the project has, and, of those with an output signature, only those whose
# signature the output matched.
class TestDetection < Minitest::Test
  include EvidenceKit

  PRESET = FunCi::Evidence::Presets::Preset
  RSPEC = PRESET.new(name: "rspec", use: "section", options: {}, markers: ["Gemfile"], signature: '^rspec \./')
  JEST = PRESET.new(name: "jest", use: "section", options: {},
                    markers: [{ "path" => "package.json", "contains" => '"jest"' }], signature: "^Tests: ")
  LOGS = PRESET.new(name: "logs", use: "json-log", options: {}, markers: [], signature: nil)
  GRADLE = PRESET.new(name: "gradle", use: "section", options: {}, markers: ["build.gradle"], signature: nil)
  FILES = { "Gemfile" => "", "package.json" => '"jest"' }.freeze
  PIECES = ["rspec", " ./", "Tests:", " ", "x"].freeze
  OVERLAPPING = [RSPEC, JEST, PRESET.new(name: "tests", use: "section", options: {}, markers: [], signature: "Tests")]
                .freeze

  def test_should_take_a_preset_whose_marker_file_exists_as_a_candidate
    assert_equal [["rspec", "file Gemfile"]], candidates({ "Gemfile" => "" }, [RSPEC, GRADLE])
  end

  def test_should_take_a_preset_without_markers_as_a_candidate_always
    assert_equal [["logs", nil]], candidates({}, [LOGS])
  end

  def test_should_take_a_preset_whose_marker_file_must_hold_a_text_only_when_it_does
    assert_equal [["jest", "file package.json"]],
                 candidates({ "package.json" => '{"devDependencies": {"jest": "29"}}' }, [JEST])
  end

  def test_should_not_take_a_preset_whose_marker_file_lacks_the_text
    assert_empty candidates({ "package.json" => '{"devDependencies": {"mocha": "10"}}' }, [JEST])
  end

  def test_should_choose_a_candidate_whose_signature_the_output_matched
    assert_equal [["rspec", "file Gemfile, output matched \"rspec ./\""]],
                 chosen("x\nrspec ./spec/a_spec.rb:4\n", [RSPEC])
  end

  def test_should_not_choose_a_candidate_whose_signature_the_output_did_not_match
    assert_empty chosen("x\ny\n", [RSPEC])
  end

  def test_should_look_for_signatures_in_the_output_s_last_part_only
    output = "rspec ./spec/a_spec.rb:4\n#{"#{"x" * 99}\n" * 3}"

    assert_empty FunCi::Evidence::Detection.chosen(output, found({ "Gemfile" => "" }, [RSPEC]), NEVER, scan_bytes: 150)
  end

  def test_should_choose_a_candidate_without_a_signature_on_its_markers_alone
    assert_equal [["gradle", "file build.gradle"]], chosen("x\n", [GRADLE], files: { "build.gradle" => "" })
  end

  def test_should_choose_every_candidate_whose_signature_matched_the_same_line
    both = PRESET.new(name: "rerun", use: "section", options: {}, markers: [], signature: "rspec")

    assert_equal %w[rspec rerun], chosen("rspec ./a_spec.rb:4\n", [RSPEC, both]).map(&:first)
  end

  # Joined, the signatures choose what each would alone, over many short
  # outputs made of their pieces (seeded, so a failure can be run again).
  def test_should_choose_what_each_signature_would_alone
    random = Random.new(seed = Random.new_seed)
    outputs = Array.new(200) { Array.new(2) { PIECES.sample(3, random: random).join }.join("\n") }

    assert_equal outputs.map { |output| one_at_a_time(output) },
                 outputs.map { |output| chosen(output, OVERLAPPING, files: FILES).map(&:first) }, "seed #{seed}"
  end

  private

  def found(files, presets) = FunCi::Evidence::Detection.candidates(FakeWorktree.new(files), presets)
  def candidates(files, presets) = found(files, presets).map { |found| [found.preset.name, found.because] }

  def chosen(output, presets, files: { "Gemfile" => "" })
    FunCi::Evidence::Detection.chosen(output, found(files, presets), NEVER)
                              .map { |found| [found.preset.name, found.because] }
  end

  def one_at_a_time(output)
    OVERLAPPING.select { |preset| output.lines.any? { |line| Regexp.new(preset.signature).match?(line.chomp) } }
               .map(&:name)
  end
end
