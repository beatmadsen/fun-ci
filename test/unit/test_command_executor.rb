# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/command_executor"

class TestCommandExecutor < Minitest::Test
  def test_a_runner_that_blows_the_budget_reports_no_output_no_status_and_a_timeout
    executor = FunCi::Pipeline::CommandExecutor.new(->(_cmd) { raise Timeout::Error })

    assert_equal ["", nil, true], executor.call("fast.sh", 10)
  end

  def test_keeps_a_runner_s_output_as_the_window_it_is_given
    window = FunCi::Pipeline::OutputWindow.in_memory(FunCi::Pipeline::OutputWindow::Sizes.new(head: 4, tail: 4))
    executor = FunCi::Pipeline::CommandExecutor.new(->(_cmd) { ["aaa\nbbbbbbbbbb\nccc\n", FakeStatus.new(false, 1)] })

    assert_equal "aaa\n[fun-ci: 11 bytes dropped here]\nccc\n", executor.call("fast.sh", 10, output: window).first
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

  def test_gives_a_runner_that_takes_one_the_command_s_environment
    seen = nil
    runner = ->(_cmd, env) { (seen = env) && ["", FakeStatus.new(true, 0)] }
    FunCi::Pipeline::CommandExecutor.new(runner).call("fast.sh", 10, env: { "FUN_CI_REPORT" => "/r" })

    assert_equal({ "FUN_CI_REPORT" => "/r" }, seen)
  end

  def test_runs_a_runner_that_takes_only_the_command_when_given_an_environment
    executor = FunCi::Pipeline::CommandExecutor.new(->(_cmd) { ["ok", FakeStatus.new(true, 0)] })

    assert_equal "ok", executor.call("fast.sh", 10, env: { "FUN_CI_REPORT" => "/r" }).first
  end
end
