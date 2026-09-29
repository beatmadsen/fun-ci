# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/console_fakes"
require "fun_ci/console/console_session"

# The console's board and events for the trunk (acceptance-tests.md, AT-11.42 to AT-11.46).
class TestConsoleSessionTrunk < Minitest::Test
  CONFLICTS = { branch_state: "conflicts", trunk: "main" }.freeze

  def setup
    @board_data = ConsoleFakes::BoardData.new([ConsoleFakes.run_row(1).merge(trunk: { branch_state: "clean",
                                                                                      trunk: "main" })])
    @port = ConsoleFakes::Port.new
    @session = FunCi::Console::ConsoleSession.build(board_data: @board_data, port: @port, clock: -> { Time.at(0) },
                                                    log: ConsoleFakes::Log.new)
    @session.start
    @session.receive('{"t":"ready","v":1,"cols":120,"rows":40}')
  end

  def test_should_mark_the_row_of_a_branch_that_conflicts
    @board_data.runs = [ConsoleFakes.run_row(2).merge(trunk: CONFLICTS)]
    @session.refresh

    assert_equal({ "branch_state" => "conflicts", "trunk" => "main" }, @port.sent.last["runs"].first["trunk"])
  end

  def test_should_send_the_conflict_before_the_board
    @board_data.runs = [ConsoleFakes.run_row(2).merge(trunk: CONFLICTS)]
    @session.refresh

    assert_equal({ "t" => "event", "name" => "trunk_conflict", "run_id" => 2, "branches" => 1 }, @port.sent[-2])
  end

  def test_should_name_the_projects_whose_trunk_is_stale
    @board_data.stale = [{ project: "/src/app", since: 1_790_000_000 }]
    @session.refresh

    assert_equal [{ "project" => "/src/app", "since" => 1_790_000_000 }], @port.sent.last["stale_trunks"]
  end

  def test_should_say_nothing_of_stale_trunks_when_none_is
    @session.refresh

    refute @port.sent.last.key?("stale_trunks")
  end
end
