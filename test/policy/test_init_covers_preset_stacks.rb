# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/evidence_fixtures"
require_relative "../support/preset_stacks"
require "fun_ci/evidence/presets"
require "fun_ci/setup/project_detector"

# AT-10.21: `fun-ci init` sets up every stack a preset reads, told by each
# preset's recorded failing project, which is a real project of its stack.
class TestInitCoversPresetStacks < Minitest::Test
  def test_should_place_every_preset_in_a_stack_or_among_the_formats
    assert_equal FunCi::Evidence::Presets.all.map(&:name).sort, PresetStacks.named.sort
  end

  PresetStacks::STACKS.each do |preset, placed|
    define_method(:"test_should_detect_the_#{preset}_recording_s_project_as_#{placed.stack}") do
      entries = EvidenceFixtures.named(preset).project_entries

      assert_equal placed.stack, FunCi::Setup::ProjectDetector.new(entries).detect
    end
  end
end
