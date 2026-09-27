# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/settings"

# The `evidence` key of .fun-ci/config (why.md, "Configuration").
class TestEvidenceSettings < Minitest::Test
  SETTINGS = FunCi::Evidence::Settings

  def test_should_give_a_budget_of_2_seconds_by_default
    assert_in_delta 2.0, SETTINGS.new(nil).budget
  end

  def test_should_read_a_budget_in_seconds
    assert_in_delta 3.5, SETTINGS.new({ "budget" => "3.5s" }).budget
  end

  def test_should_list_the_entries_for_every_stage_before_the_stage_s_own
    raw = { "stages" => { "fast" => [{ "use" => "b" }], "all" => [{ "use" => "a" }] } }

    assert_equal [{ "use" => "a" }, { "use" => "b" }], SETTINGS.new(raw).entries("fast")
  end

  def test_should_list_no_entries_for_a_stage_it_does_not_name
    assert_empty SETTINGS.new({ "stages" => { "fast" => [{ "use" => "b" }] } }).entries("slow")
  end

  def test_should_detect_presets_by_default
    assert SETTINGS.new(nil).detect?
  end

  def test_should_mask_by_default
    assert SETTINGS.new(nil).masking?
  end

  def test_should_compile_the_project_s_mask_patterns
    assert_equal([/ACME-\d+/], SETTINGS.new({ "mask" => ['ACME-\d+'] }).mask_patterns.map do |re|
      Regexp.new(re.source)
    end)
  end

  def test_should_name_the_presets_to_skip
    assert_equal %w[pino], SETTINGS.new({ "skip" => %w[pino] }).skip
  end

  def test_should_report_a_budget_it_cannot_read
    assert_equal ["evidence.budget must be a number of seconds such as 2 or 2s, not \"soon\""],
                 SETTINGS.new({ "budget" => "soon" }).errors
  end

  def test_should_report_a_setting_it_does_not_know
    assert_equal ["evidence has no setting 'budgets'"], SETTINGS.new({ "budgets" => 2 }).errors
  end

  def test_should_report_a_stage_it_does_not_know
    assert_equal ["evidence.stages has no stage 'quick': use all, lint, build, fast or slow"],
                 SETTINGS.new({ "stages" => { "quick" => [] } }).errors
  end

  def test_should_report_each_entry_s_mistake_with_its_stage
    assert_equal ["evidence.stages.fast: unknown extractor 'nosuch'"],
                 SETTINGS.new({ "stages" => { "fast" => [{ "use" => "nosuch" }] } }).errors
  end

  def test_should_use_its_defaults_when_evidence_is_not_a_mapping
    assert_in_delta 2.0, SETTINGS.new("lots").budget
  end

  def test_should_report_evidence_that_is_not_a_mapping
    assert_equal ["evidence must be a mapping, not \"lots\""], SETTINGS.new("lots").errors
  end
end
