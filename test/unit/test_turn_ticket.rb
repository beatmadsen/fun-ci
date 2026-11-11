# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/turn_queue"

# A ticket's name is how TurnQueue tells the newer suites: names sort as the
# suites' runs arrived on the branch (acceptance-tests.md, AT-9.20).
class TestTurnTicket < Minitest::Test
  TICKET = FunCi::Pipeline::TurnTicket

  def test_should_sort_a_later_commit_s_ticket_after_an_earlier_one_s_whatever_their_stages
    assert_operator TICKET.new(place: 5, id: 1).name, :>, TICKET.new(place: 3, id: 9).name
  end

  def test_should_sort_places_as_numbers
    assert_operator TICKET.new(place: 10, id: 1).name, :>, TICKET.new(place: 9, id: 1).name
  end

  # Of two runs of one commit, the later is the newer.
  def test_should_sort_a_later_run_of_the_same_commit_after_the_earlier
    assert_operator TICKET.new(place: 3, id: 10).name, :>, TICKET.new(place: 3, id: 9).name
  end
end
