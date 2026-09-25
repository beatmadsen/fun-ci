# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/command_executor"

class TestCommandExecutor < Minitest::Test
  def test_a_runner_that_blows_the_budget_reports_no_output_no_status_and_a_timeout
    executor = FunCi::Pipeline::CommandExecutor.new(->(_cmd) { raise Timeout::Error })

    assert_equal ["", nil, true], executor.call("fast.sh", 10)
  end

  def test_passes_on_the_process_the_command_started
    started = []
    runner = lambda do |_cmd, &on_start|
      on_start.call(4242)
      ["", FakeStatus.new(true, 0)]
    end
    FunCi::Pipeline::CommandExecutor.new(runner).call("fast.sh", 10) { |pid| started << pid }

    assert_equal [4242], started
  end

  def test_a_runner_that_finishes_reports_its_output_and_status_and_no_timeout
    status = FakeStatus.new(true, 0)
    executor = FunCi::Pipeline::CommandExecutor.new(->(_cmd) { ["ok", status] })

    assert_equal ["ok", status, false], executor.call("fast.sh", 10)
  end
end
