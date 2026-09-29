# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/trunk_events"

# The header's events for branches that start or stop conflicting with the
# trunk (acceptance-tests.md, AT-11.44, AT-11.45).
class TestConsoleTrunkEvents < Minitest::Test
  def setup = @events = FunCi::Console::TrunkEvents.new

  def test_should_send_nothing_on_the_first_poll
    assert_empty @events.since_last([board_run(1, "feat/a", "conflicts")])
  end

  def test_should_send_a_conflict_when_a_branch_starts_conflicting
    @events.since_last([board_run(1, "feat/a", "clean")])

    assert_equal [{ t: "event", name: "trunk_conflict", run_id: 2, branches: 1 }],
                 @events.since_last([board_run(2, "feat/a", "conflicts")])
  end

  def test_should_send_a_clear_when_a_branch_stops_conflicting
    @events.since_last([board_run(1, "feat/a", "conflicts")])

    assert_equal(["trunk_clear"], @events.since_last([board_run(2, "feat/a", "up_to_date")]).map do |event|
      event[:name]
    end)
  end

  def test_should_send_nothing_for_a_branch_whose_standing_did_not_change
    @events.since_last([board_run(1, "feat/a", "conflicts")])

    assert_empty @events.since_last([board_run(2, "feat/a", "conflicts")])
  end

  def test_should_send_nothing_when_a_branch_has_no_standing_this_poll
    @events.since_last([board_run(1, "feat/a", "conflicts")])

    assert_empty @events.since_last([board_run(2, "feat/a", nil)])
  end

  def test_should_send_one_event_for_every_branch_that_starts_conflicting_in_one_poll
    @events.since_last([board_run(1, "feat/a", "clean"), board_run(2, "feat/b", "clean"),
                        board_run(3, "feat/c", "clean")])
    now = [board_run(4, "feat/a", "conflicts"), board_run(5, "feat/b", "conflicts"),
           board_run(6, "feat/c", "conflicts")]

    assert_equal [{ t: "event", name: "trunk_conflict", run_id: 4, branches: 3 }], @events.since_last(now)
  end

  def test_should_tell_the_same_branch_of_two_projects_apart
    @events.since_last([board_run(1, "main", "clean", project: "/a")])

    assert_equal(["trunk_conflict"], @events.since_last([board_run(2, "main", "conflicts", project: "/b")])
                                            .map { |event| event[:name] })
  end

  private

  def board_run(id, branch, state, project: "/a")
    { id: id, branch: branch, project_path: project, trunk: state && { branch_state: state, trunk: "main" } }
  end
end
