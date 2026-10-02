# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/trigger_params"

# Each seam a pipeline is given none of gets the real thing.
class TestSeams < Minitest::Test
  # nil is the project's own trunk, which Trunk::Checker finds (test_trigger_default_trunk.rb).
  def test_should_leave_the_trunk_to_the_project_s_own_when_none_is_given
    assert_nil FunCi::Pipeline::Seams.new.trunk
  end

  def test_should_start_jobs_and_the_slow_suite_as_this_platform_s_priorities_say
    assert_equal FunCi::Pipeline::Priorities.for(RUBY_PLATFORM), FunCi::Pipeline::Seams.new.priorities
  end
end
