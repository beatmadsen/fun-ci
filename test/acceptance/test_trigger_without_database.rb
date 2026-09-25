# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"

# Trigger's default recorder keeps nothing and has no database, so there are
# no earlier runs to cancel; the pipeline still runs.
class TestTriggerWithoutDatabase < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def test_should_run_a_pipeline_with_nothing_recording_it
    assert_equal(0, in_project { |dir| build_trigger(dir, command_runner: scripted_runner).run })
  end
end
