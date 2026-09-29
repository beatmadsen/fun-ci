# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/preset_stacks"
require_relative "../../script/suites_apart"
require "fun_ci/setup/project_detector"

# Every stack init detects is either measured by the weekly check of stages
# side by side, through a recording whose fast script runs its tool, or named
# with the reason it isn't, so a new stack can't go unmeasured unnoticed.
class TestSuitesApartCoverage < Minitest::Test
  def test_should_measure_or_name_every_stack_init_detects
    measured = PresetStacks::STACKS.values.select { _1.stage == "fast.sh" }.map(&:stack)

    assert_equal FunCi::Setup::ProjectDetector::STACKS.keys.sort,
                 (measured | SuitesApart::UNMEASURED.keys).sort
  end

  def test_should_name_no_stack_that_is_measured_as_unmeasured
    measured = PresetStacks::STACKS.values.select { _1.stage == "fast.sh" }.map(&:stack)

    assert_empty measured & SuitesApart::UNMEASURED.keys
  end
end
