# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/agent/live_pipeline"

# `wait` can't start a run in a project not set up for fun-ci (AT-9.11).
class TestLivePipelineSetup < Minitest::Test
  def test_should_start_nothing_in_a_project_without_fun_ci
    Dir.mktmpdir("not-set-up") { |dir| assert_nil FunCi::Agent::LivePipeline.new(dir).start("abc1234", "main") }
  end
end
