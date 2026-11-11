# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"
require "fun_ci/pipeline/budgets"

# Mutineer checks the unmutated tests together before it scores, within its
# capture timeout, and reports one that overruns as a suite that is not
# green. That check runs every test file it is given in one process, which a
# loaded machine took past the 120 s default (seen on d59fecc's slow stage).
# Here the slow stage's budget is the one time limit: below it, a slow
# check would read as failing tests.
class TestMutationCaptureTimeout < Minitest::Test
  CONFIG = File.expand_path("../../.mutineer.yml", __dir__)

  def test_should_give_mutineer_s_unmutated_check_the_slow_stage_s_budget
    assert_equal FunCi::Pipeline::DEFAULT_BUDGETS.fetch("slow"), YAML.safe_load_file(CONFIG)["capture_timeout"]
  end
end
